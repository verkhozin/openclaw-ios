import Foundation
import Combine

/// Main service: WebSocket connection to OpenClaw Gateway.
/// All data flows through here.
@MainActor
class GatewayService: ObservableObject {
    static let shared = GatewayService()
    
    // MARK: - Published state
    @Published var isPaired: Bool = false
    @Published var status: GatewayStatus = GatewayStatus()
    @Published var messages: [Message] = []
    @Published var tasks: [AgentTask] = []
    @Published var cronJobs: [CronJob] = []
    
    // MARK: - Connection
    private var webSocket: URLSessionWebSocketTask?
    private var gatewayURL: URL?
    private var authToken: String?
    private var deviceToken: String?
    private var deviceId: String?
    private var pendingRequests: [String: CheckedContinuation<WSResponse, Error>] = [:]
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt: Int = 0
    private let maxReconnectDelay: TimeInterval = 30
    
    /// Card types this client supports (sent at connect)
    let supportedCardTypes: [String] = [
        "github.pr", "github.issue", "github.ci",
        "email.inbox", "email.draft", "email.digest",
        "calendar.event", "calendar.conflict",
        "linear.issue",
        "file.preview", "file.diff",
        "lead", "task.status", "usage"
    ]
    
    private init() {
        deviceId = getOrCreateDeviceId()
        loadPairing()
    }
    
    // MARK: - Pairing
    
    func pair(url: URL, token: String) {
        gatewayURL = url
        authToken = token
        savePairing()
        isPaired = true
        connect()
    }
    
    func unpair() {
        reconnectTask?.cancel()
        reconnectTask = nil
        disconnect()
        gatewayURL = nil
        authToken = nil
        deviceToken = nil
        clearPairing()
        isPaired = false
        messages.removeAll()
        tasks.removeAll()
        cronJobs.removeAll()
    }
    
    // MARK: - WebSocket Connection
    
    func connect() {
        guard let url = gatewayURL else { return }
        guard let token = authToken else { return }
        
        disconnect()
        
        let wsURL = buildWebSocketURL(from: url)
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: wsURL)
        webSocket?.resume()
        
        // Start receive loop
        receiveLoop()
        
        // Send connect handshake
        let connectReq = GatewayHandshake.connectRequest(
            token: token,
            deviceId: deviceId ?? "unknown",
            cardTypes: supportedCardTypes
        )
        sendFrame(connectReq)
    }
    
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        status.isConnected = false
    }
    
    // MARK: - Send Message to Agent
    
    func sendMessage(_ text: String) {
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        
        // Create a placeholder agent message for streaming
        let agentMessage = Message(role: .agent, content: "", isStreaming: true)
        messages.append(agentMessage)
        
        let req = WSRequest(method: GatewayMethod.agent, params: [
            "message": AnyCodable(text)
        ])
        sendFrame(req)
    }
    
    // MARK: - Cron
    
    func toggleCron(_ job: CronJob) {
        let req = WSRequest(method: GatewayMethod.cronUpdate, params: [
            "jobId": AnyCodable(job.id),
            "patch": AnyCodable(["enabled": !job.enabled])
        ])
        sendFrame(req)
        
        // Optimistic update
        if let idx = cronJobs.firstIndex(where: { $0.id == job.id }) {
            cronJobs[idx].enabled.toggle()
        }
    }
    
    func runCron(_ job: CronJob) {
        let req = WSRequest(method: GatewayMethod.cronRun, params: [
            "jobId": AnyCodable(job.id)
        ])
        sendFrame(req)
    }
    
    // MARK: - Exec Approval
    
    func resolveApproval(requestId: String, approved: Bool) {
        let req = WSRequest(method: GatewayMethod.execApprovalResolve, params: [
            "requestId": AnyCodable(requestId),
            "resolution": AnyCodable(approved ? "allow-once" : "deny")
        ])
        sendFrame(req)
    }
    
    // MARK: - WebSocket Send
    
    private func sendFrame<T: Encodable>(_ frame: T) {
        guard let data = try? JSONEncoder().encode(frame),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(string)) { [weak self] error in
            if let error {
                print("[WS] Send error: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.handleDisconnect()
                }
            }
        }
    }
    
    // MARK: - WebSocket Receive
    
    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self.handleFrame(WSFrame.parse(data))
                        }
                    case .data(let data):
                        self.handleFrame(WSFrame.parse(data))
                    @unknown default:
                        break
                    }
                    // Continue receiving
                    self.receiveLoop()
                    
                case .failure(let error):
                    print("[WS] Receive error: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }
    
    // MARK: - Frame Handler
    
    private func handleFrame(_ frame: WSFrame) {
        switch frame {
        case .response(let res):
            handleResponse(res)
        case .event(let evt):
            handleEvent(evt)
        case .unknown(let data):
            print("[WS] Unknown frame: \(String(data: data, encoding: .utf8) ?? "?")")
        }
    }
    
    private func handleResponse(_ res: WSResponse) {
        // Check for connect response (hello-ok)
        if res.ok,
           let payload = res.payload,
           let type = payload["type"]?.value as? String,
           type == "hello-ok" {
            status.isConnected = true
            reconnectAttempt = 0
            
            // Store device token if provided
            if let auth = payload["auth"]?.value as? [String: Any],
               let devToken = auth["deviceToken"] as? String {
                deviceToken = devToken
                KeychainService.save(key: "deviceToken", value: devToken)
            }
            return
        }
        
        // Check for error
        if !res.ok {
            print("[WS] Error response: \(res.error?.message ?? "unknown")")
        }
        
        // Resume pending async request if any
        if let continuation = pendingRequests.removeValue(forKey: res.id) {
            continuation.resume(returning: res)
        }
    }
    
    private func handleEvent(_ evt: WSEvent) {
        switch evt.event {
        case GatewayEvent.connectChallenge:
            // Server sends challenge before we connect.
            // For now we proceed without signing (basic token auth).
            break
            
        case GatewayEvent.agent, GatewayEvent.agentStream:
            handleAgentEvent(evt)
            
        case GatewayEvent.tick:
            // Keep-alive tick, no action needed
            break
            
        case GatewayEvent.presence:
            // Could update online devices list
            break
            
        case GatewayEvent.execApproval:
            handleExecApproval(evt)
            
        case GatewayEvent.shutdown:
            handleDisconnect()
            
        default:
            print("[WS] Unhandled event: \(evt.event)")
        }
    }
    
    // MARK: - Agent Event Handling
    
    private func handleAgentEvent(_ evt: WSEvent) {
        guard let payload = evt.payload else { return }
        
        // Find the last streaming agent message
        guard let idx = messages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) else { return }
        
        if let chunk = payload["chunk"]?.value as? String {
            // Streaming chunk -- append to current message
            messages[idx].content += chunk
        }
        
        if let status = payload["status"]?.value as? String {
            if status == "completed" || status == "done" {
                messages[idx].isStreaming = false
                
                // Parse service cards from completed message
                let parsed = CardParser.parse(messages[idx].content)
                if !parsed.cards.isEmpty {
                    messages[idx].content = parsed.cleanText
                    messages[idx].serviceCard = parsed.cards.first
                }
            } else if status == "error" {
                messages[idx].isStreaming = false
                if messages[idx].content.isEmpty {
                    messages[idx].content = payload["error"]?.value as? String ?? "Agent error"
                }
            }
        }
    }
    
    // MARK: - Exec Approval Handling
    
    private func handleExecApproval(_ evt: WSEvent) {
        guard let payload = evt.payload,
              let requestId = payload["requestId"]?.value as? String,
              let command = payload["command"]?.value as? String else { return }
        
        // Add as system message so UI can show approve/deny
        let msg = Message(
            role: .system,
            content: "Approval needed: \(command)",
            serviceCard: ServiceCard(
                type: .unknown,
                fields: ["requestId": requestId, "command": command]
            )
        )
        messages.append(msg)
    }
    
    // MARK: - Reconnection
    
    private func handleDisconnect() {
        status.isConnected = false
        webSocket = nil
        
        guard isPaired else { return }
        
        reconnectTask?.cancel()
        reconnectTask = Task {
            reconnectAttempt += 1
            let delay = min(pow(2.0, Double(reconnectAttempt)), maxReconnectDelay)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            connect()
        }
    }
    
    // MARK: - Helpers
    
    private func buildWebSocketURL(from url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        // Ensure ws:// scheme
        if components.scheme == "http" { components.scheme = "ws" }
        if components.scheme == "https" { components.scheme = "wss" }
        if components.scheme == nil { components.scheme = "ws" }
        // Default port
        if components.port == nil { components.port = 18789 }
        return components.url!
    }
    
    private func getOrCreateDeviceId() -> String {
        if let existing = KeychainService.load(key: "deviceId") {
            return existing
        }
        let newId = UUID().uuidString
        KeychainService.save(key: "deviceId", value: newId)
        return newId
    }
    
    // MARK: - Persistence (Keychain)
    
    private func savePairing() {
        if let url = gatewayURL {
            KeychainService.save(key: "gatewayURL", value: url.absoluteString)
        }
        if let token = authToken {
            KeychainService.save(key: "authToken", value: token)
        }
    }
    
    private func loadPairing() {
        guard let urlStr = KeychainService.load(key: "gatewayURL"),
              let url = URL(string: urlStr),
              let token = KeychainService.load(key: "authToken") else {
            isPaired = false
            return
        }
        
        gatewayURL = url
        authToken = token
        deviceToken = KeychainService.load(key: "deviceToken")
        isPaired = true
        
        // Auto-connect on launch
        connect()
    }
    
    private func clearPairing() {
        KeychainService.delete(key: "gatewayURL")
        KeychainService.delete(key: "authToken")
        KeychainService.delete(key: "deviceToken")
    }
}
