import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "GatewayService")

/// Main service: WebSocket connection to OpenClaw Gateway
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
    @Published var connectionLog: [String] = []

    let sessionStore = SessionStore.shared

    // MARK: - Connection
    // nonisolated(unsafe) so the fast-path challenge handler can read these
    // without hopping to MainActor. Only written on MainActor.
    nonisolated(unsafe) private var webSocket: URLSessionWebSocketTask?
    nonisolated(unsafe) private(set) var gatewayURL: URL?
    nonisolated(unsafe) private(set) var authToken: String?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectAttempt: Int = 0
    private let maxReconnectAttempts = 5

    private init() {
        logger.info("GatewayService init")
        loadPairing()
        if isPaired {
            logger.info("Restored pairing from Keychain — url=\(self.gatewayURL?.absoluteString ?? "nil", privacy: .public)")
            log("Restored pairing from Keychain")
        } else {
            logger.info("No saved pairing found")
        }
    }

    // MARK: - Pairing

    func pair(url: URL, token: String) {
        logger.info("Pairing with \(url.absoluteString, privacy: .public)")
        log("Pairing with \(url.absoluteString)")
        gatewayURL = url
        authToken = token
        savePairing()
        isPaired = true
        reconnectAttempt = 0
        connect()
    }

    func unpair() {
        logger.info("Unpairing — clearing credentials")
        log("Unpairing — clearing credentials and disconnecting")
        disconnect()
        gatewayURL = nil
        authToken = nil
        clearPairing()
        isPaired = false
        connectionLog.removeAll()
    }

    // MARK: - WebSocket
    //
    // Protocol flow (single socket):
    //   1. Open WebSocket
    //   2. Receive connect.challenge with nonce
    //   3. Send connect req frame with nonce on SAME socket
    //   4. Receive hello-ok

    func connect() {
        guard let url = gatewayURL else {
            logger.warning("connect() called but no URL")
            log("Cannot connect — no URL")
            return
        }

        disconnect()
        reconnectAttempt = 0

        logger.info("Opening WebSocket to \(url.absoluteString, privacy: .public)")
        log("Connecting to \(url.absoluteString)...")

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        self.session = session

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let task = session.webSocketTask(with: request)
        self.webSocket = task

        log("WebSocket task created (timeout: 10s)")
        task.resume()

        log("Waiting for connect.challenge...")
        logger.info("WebSocket opened — waiting for connect.challenge")
        receiveLoop()
    }

    func disconnect() {
        stopPingTimer()
        if webSocket != nil {
            logger.info("Disconnecting WebSocket")
            log("Closing WebSocket connection")
        }
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session = nil
        status.isConnected = false
    }

    // MARK: - Handshake: respond to connect.challenge on same socket

    private nonisolated func sendConnectReq(nonce: String) {
        guard let token = self.authToken else {
            logger.error("sendConnectReq: no auth token")
            return
        }

        let signedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let signature = DeviceCrypto.signChallenge(
            nonce: nonce,
            token: token,
            signedAtMs: signedAtMs
        )

        let connectFrame: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "connect",
            "params": [
                "minProtocol": 3,
                "maxProtocol": 3,
                "client": [
                    "id": "openclaw-ios",
                    "version": "1.0.0",
                    "platform": "ios",
                    "mode": "ui"
                ] as [String: Any],
                "role": "operator",
                "scopes": ["operator.read", "operator.write", "operator.approvals", "operator.pairing"],
                "caps": ["cards.v1"],
                "commands": [] as [String],
                "permissions": [:] as [String: Any],
                "auth": [
                    "token": token
                ] as [String: Any],
                "device": [
                    "id": DeviceCrypto.deviceId,
                    "publicKey": DeviceCrypto.publicKeyBase64URL,
                    "signature": signature,
                    "signedAt": signedAtMs,
                    "nonce": nonce
                ] as [String: Any],
                "locale": "en-US",
                "userAgent": "CLiOS/1.0.0"
            ] as [String: Any]
        ]

        guard let frameData = try? JSONSerialization.data(withJSONObject: connectFrame),
              let frameText = String(data: frameData, encoding: .utf8) else {
            logger.error("Failed to serialize connect req frame")
            Task { @MainActor in self.log("ERROR: failed to serialize connect frame") }
            return
        }

        logger.info("Sending connect req with device signature (\(frameText.count) chars)")
        Task { @MainActor in
            self.log("OUT connect req (\(frameText.count) chars, device: \(DeviceCrypto.deviceId.prefix(12))...)")
        }

        self.webSocket?.send(.string(frameText)) { error in
            if let error {
                logger.error("Connect req send failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self.log("Connect req FAILED: \(error.localizedDescription)")
                    self.scheduleReconnect()
                }
            } else {
                logger.info("Connect req sent — waiting for hello-ok")
                Task { @MainActor in
                    self.log("Connect req sent — waiting for hello-ok...")
                }
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        reconnectAttempt += 1
        guard reconnectAttempt <= maxReconnectAttempts else {
            logger.error("Max reconnect attempts (\(self.maxReconnectAttempts)) reached — giving up")
            log("Max reconnect attempts reached — giving up. Tap Connect to retry.")
            return
        }

        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        logger.info("Scheduling reconnect #\(self.reconnectAttempt) in \(delay, privacy: .public)s")
        log("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempt)/\(maxReconnectAttempts))...")

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.isPaired, !self.status.isConnected else { return }
            logger.info("Reconnect attempt #\(self.reconnectAttempt)")
            self.log("Reconnect attempt #\(self.reconnectAttempt)...")
            self.connect()
        }
    }

    // MARK: - Ping keepalive

    private func startPingTimer() {
        stopPingTimer()
        logger.debug("Starting ping timer (every 30s)")
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendProtocolPing()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendProtocolPing() {
        guard let ws = webSocket else { return }
        ws.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    logger.warning("Protocol ping failed: \(error.localizedDescription, privacy: .public)")
                    self.log("Keepalive ping failed: \(error.localizedDescription)")
                    self.status.isConnected = false
                    self.scheduleReconnect()
                } else {
                    logger.debug("Protocol ping OK")
                }
            }
        }
    }

    // MARK: - Receive loop

    private func receiveLoop() {
        guard let ws = webSocket else {
            logger.warning("receiveLoop: no webSocket")
            return
        }

        ws.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                let text: String?
                switch message {
                case .string(let s):
                    logger.debug("Received text frame (\(s.count) chars)")
                    text = s
                case .data(let d):
                    logger.debug("Received binary frame (\(d.count) bytes)")
                    text = String(data: d, encoding: .utf8)
                @unknown default:
                    logger.warning("Unknown WebSocket message type")
                    text = nil
                }

                if let text {
                    // Fast path: respond to challenge immediately without MainActor hop
                    if self.tryHandleChallenge(text) {
                        // handled
                    } else {
                        Task { @MainActor in
                            self.handleFrame(text)
                        }
                    }
                }

                self.receiveLoop()

            case .failure(let error):
                let nsError = error as NSError
                logger.error("WebSocket receive error: \(error.localizedDescription, privacy: .public) (code: \(nsError.code))")
                Task { @MainActor in
                    self.log("Connection lost: \(error.localizedDescription) [code \(nsError.code)]")
                    self.status.isConnected = false
                    self.stopPingTimer()
                    self.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - Fast-path challenge handler (runs on callback thread)

    /// Returns true if this frame was a connect.challenge and was handled.
    private nonisolated func tryHandleChallenge(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return false
        }

        let eventName: String
        if type == "event", let event = json["event"] as? String {
            eventName = event
        } else {
            eventName = type
        }

        guard eventName == "connect.challenge" else { return false }

        let payload = json["payload"] as? [String: Any]
        guard let nonce = payload?["nonce"] as? String else {
            logger.error("connect.challenge missing nonce")
            Task { @MainActor in self.log("ERROR: connect.challenge missing nonce") }
            return true
        }

        let challengeTs = payload?["ts"] as? Int64
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let latency = challengeTs.map { now - $0 } ?? 0

        logger.info("Challenge received: nonce=\(nonce, privacy: .public) latency=\(latency)ms")
        Task { @MainActor in
            self.log("IN  \(String(text.prefix(300)))")
            self.log("Challenge received (nonce: \(nonce.prefix(12))..., latency: \(latency)ms)")
            self.log("Responding with connect req on same socket...")
        }

        // Respond immediately on this thread — same socket
        sendConnectReq(nonce: nonce)
        return true
    }

    // MARK: - Frame handling

    private func handleFrame(_ text: String) {
        let preview = String(text.prefix(300))
        log("IN  \(preview)")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            logger.warning("Cannot parse frame as JSON")
            log("Cannot parse frame as JSON")
            return
        }

        // Gateway frame formats:
        //   { "type": "event", "event": "...", "payload": {...} }
        //   { "type": "res", "id": "...", "result": {...} }
        //   { "type": "error", ... }
        //   { "type": "pong" }
        let eventName: String
        if type == "event", let event = json["event"] as? String {
            eventName = event
        } else if type == "res" {
            eventName = "res"
        } else {
            eventName = type
        }

        logger.info("Frame type=\(type, privacy: .public) event=\(eventName, privacy: .public)")

        switch eventName {
        case "connect.challenge":
            // Normally handled by tryHandleChallenge fast-path; fallback here
            let payload = json["payload"] as? [String: Any]
            if let nonce = payload?["nonce"] as? String {
                log("Received connect.challenge (slow path, nonce: \(nonce.prefix(12))...)")
                sendConnectReq(nonce: nonce)
            } else {
                log("ERROR: connect.challenge missing nonce")
            }

        case "res":
            // Response to a req frame (e.g. connect req → hello-ok)
            handleResponse(json)

        case "hello-ok", "welcome", "connected":
            logger.info("Gateway confirmed connection (event: \(eventName, privacy: .public))")
            log("Connected! (\(eventName))")
            status.isConnected = true
            reconnectAttempt = 0
            startPingTimer()
            let src = json["payload"] as? [String: Any] ?? json
            if let ver = src["version"] as? String {
                status.version = ver
                log("  version: \(ver)")
            }
            if let model = src["model"] as? String {
                status.model = model
                log("  model: \(model)")
            }
            if let name = src["agentName"] as? String {
                status.agentName = name
                log("  agent: \(name)")
            }

        case "chat":
            // Chat events: payload.state = "delta" | "final"
            // payload.message.content[0].text = "..."
            let src = json["payload"] as? [String: Any] ?? json
            let state = src["state"] as? String ?? ""
            // Use sessionKey from payload; fallback to current open session, then mainSessionKey
            let sessionKey = (src["sessionKey"] as? String)
                ?? (sessionStore.currentSessionKey.isEmpty ? status.mainSessionKey : sessionStore.currentSessionKey)
            let seq = (src["seq"] as? Int64) ?? Int64(src["seq"] as? Int ?? 0)
            let msg = src["message"] as? [String: Any]
            let contentArr = msg?["content"] as? [[String: Any]]
            let text = contentArr?.first?["text"] as? String ?? ""
            let ts = (msg?["timestamp"] as? Int64) ?? Int64(Date().timeIntervalSince1970 * 1000)
            let runId = src["runId"] as? String

            if !text.isEmpty {
                // Persist via SessionStore (handles cache, unread, UI update)
                sessionStore.handleChatEvent(
                    sessionKey: sessionKey,
                    state: state,
                    text: text,
                    seq: seq,
                    timestamp: ts,
                    runId: runId
                )

                // Also update legacy messages array for existing views
                if state == "final" {
                    if let last = messages.last, last.role == .agent, last.isStreaming {
                        messages[messages.count - 1].content = text
                        messages[messages.count - 1].isStreaming = false
                    } else {
                        messages.append(Message(role: .agent, content: text, isStreaming: false))
                    }
                    log("Agent response complete (\(text.count) chars)")
                } else if state == "delta" {
                    if let last = messages.last, last.role == .agent, last.isStreaming {
                        messages[messages.count - 1].content = text
                    } else {
                        messages.append(Message(role: .agent, content: text, isStreaming: true))
                        log("Agent started responding")
                    }
                }
            }

        case "agent", "event:agent":
            guard let agentEvent = AgentEvent.from(json) else {
                logger.warning("Could not parse agent event")
                break
            }
            handleAgentEvent(agentEvent)

        case "status", "event:status":
            let src = json["payload"] as? [String: Any] ?? json
            if let connected = src["connected"] as? Bool {
                status.isConnected = connected
                log("Status update: connected=\(connected)")
            }
            if let session = src["sessionPercent"] as? Double {
                status.sessionPercent = session
            }
            if let weekly = src["weeklyPercent"] as? Double {
                status.weeklyPercent = weekly
            }

        case "task", "event:task":
            let src = json["payload"] as? [String: Any] ?? json
            log("Task event: \(src["status"] as? String ?? "?")")

        case "error":
            let src = json["payload"] as? [String: Any] ?? json
            let msg = src["message"] as? String ?? json["message"] as? String ?? "Unknown error"
            let code = src["code"] as? String ?? json["code"] as? String ?? ""
            log("ERROR from gateway: \(msg)\(code.isEmpty ? "" : " [\(code)]")")

        case "health":
            let src = json["payload"] as? [String: Any] ?? json
            let ok = src["ok"] as? Bool ?? false
            logger.debug("Health event: ok=\(ok)")
            // Don't log every health check — too noisy

        case "tick":
            // Heartbeat from gateway — silent
            break

        case "pong":
            log("Pong received")

        default:
            log("Unhandled event: \(eventName)")
        }
    }

    // MARK: - Handle "res" frames (responses to our "req" frames)

    private func handleResponse(_ json: [String: Any]) {
        let payload = json["payload"] as? [String: Any] ?? [:]
        let payloadType = payload["type"] as? String

        if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "Unknown error"
            let code = error["code"] as? Int
            log("Response error: \(msg)\(code.map { " [code \($0)]" } ?? "")")
            return
        }

        // "ok" is at root level: {"type":"res","ok":true,"payload":{"type":"hello-ok",...}}
        let ok = json["ok"] as? Bool ?? false

        if ok && payloadType == "hello-ok" {
            let server = payload["server"] as? [String: Any] ?? [:]
            let version = server["version"] as? String ?? "unknown"
            let connId = server["connId"] as? String ?? ""

            log("Connected to gateway!")
            log("  server: v\(version)")
            log("  connId: \(connId.prefix(12))...")
            status.isConnected = true
            status.version = version
            status.connId = connId

            // Extract mainSessionKey from snapshot
            let snapshot = payload["snapshot"] as? [String: Any] ?? [:]
            let sessionDefaults = snapshot["sessionDefaults"] as? [String: Any] ?? [:]
            if let mainKey = sessionDefaults["mainSessionKey"] as? String {
                status.mainSessionKey = mainKey
                log("  sessionKey: \(mainKey)")

                // Initialize session in store and open it
                sessionStore.ensureSession(key: mainKey, title: "Main")
                sessionStore.openSession(key: mainKey)

                // Notify agent that this client supports cards
                sendSystemEvent(sessionKey: mainKey)
            }

            // Drain offline outbox
            sessionStore.drainOutbox { [weak self] sessionKey, content, idempotencyKey in
                await (self?.sendChatMessage(sessionKey: sessionKey, content: content, idempotencyKey: idempotencyKey) ?? false)
            }
            reconnectAttempt = 0
            startPingTimer()
        } else if ok {
            log("Response OK (payload type: \(payloadType ?? "?"))")
        } else {
            log("Response received (ok=\(ok), type: \(payloadType ?? "?"))")
        }
    }

    // MARK: - Agent event handling

    /// Tracks which runId is currently streaming, so we update the right message.
    private var activeRunId: String?

    private func handleAgentEvent(_ event: AgentEvent) {
        switch event.stream {
        case .lifecycleStart:
            activeRunId = event.runId
            logger.info("Agent run started: \(event.runId.prefix(12))")
            log("Agent started (run: \(event.runId.prefix(12))...)")
            // Insert a streaming placeholder in both stores
            let m = Message(role: .agent, content: "", isStreaming: true)
            messages.append(m)
            let sessionKey = sessionStore.currentSessionKey.isEmpty
                ? status.mainSessionKey
                : sessionStore.currentSessionKey
            sessionStore.beginAgentResponse(sessionKey: sessionKey)

        case .assistant(let text, _):
            // Update the current streaming message with full text
            if let idx = messages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                messages[idx].content = text
            } else {
                let m = Message(role: .agent, content: text, isStreaming: true)
                messages.append(m)
            }
            // Also update SessionStore streaming message
            if let idx = sessionStore.currentMessages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                sessionStore.currentMessages[idx].content = text
            }

        case .lifecycleEnd:
            logger.info("Agent run ended: \(event.runId.prefix(12))")
            log("Agent finished (run: \(event.runId.prefix(12))...)")
            // Finalize legacy messages
            if let idx = messages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                messages[idx].isStreaming = false
                messages[idx].blocks = MessageParser.parse(messages[idx].content)
            }
            // Finalize SessionStore streaming message
            sessionStore.finalizeAgentResponse()
            activeRunId = nil
        }
    }

    // MARK: - Send message to agent

    // MARK: - System event (notify agent of client capabilities)

    private func sendSystemEvent(sessionKey: String) {
        let frame: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "system-event",
            "params": [
                "text": "CLiOS client connected. This session supports cards.v1 rich cards. Use card:type codeblocks for structured data.",
                "sessionKey": sessionKey
            ] as [String: Any]
        ]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                if success {
                    self?.log("Sent system-event (cards.v1 capability)")
                } else {
                    self?.log("Failed to send system-event")
                }
            }
        }
    }

    // MARK: - Send message to agent

    func sendMessage(_ text: String) {
        let sessionKey = sessionStore.currentSessionKey.isEmpty
            ? status.mainSessionKey
            : sessionStore.currentSessionKey
        logger.info("Sending message to agent (\(text.count) chars) session=\(sessionKey, privacy: .public)")
        log("OUT chat.send (\(text.count) chars)")

        // Persist user message via SessionStore
        let prepared = sessionStore.prepareSend(text: text, sessionKey: sessionKey)

        // Also keep legacy messages array in sync
        let message = Message(role: .user, content: text)
        messages.append(message)

        let frame: [String: Any] = [
            "type": "req",
            "id": prepared.messageId,
            "method": "chat.send",
            "params": [
                "sessionKey": sessionKey,
                "message": text,
                "idempotencyKey": prepared.idempotencyKey
            ]
        ]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.log("Message delivered to gateway")
                } else {
                    self.log("Failed to send message — queuing for retry")
                    // Queue for offline retry
                    self.sessionStore.enqueueOffline(
                        messageId: prepared.messageId,
                        sessionKey: sessionKey,
                        content: text,
                        idempotencyKey: prepared.idempotencyKey
                    )
                }
            }
        }
    }

    // MARK: - Ping (application-level)

    func sendPing() {
        log("OUT ping")
        let frame: [String: Any] = ["type": "ping"]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                if success {
                    self?.log("Ping sent — waiting for pong...")
                } else {
                    self?.log("Ping failed — WebSocket may be closed")
                }
            }
        }
    }

    // MARK: - Request status

    func requestStatus() {
        log("OUT req:status")
        let frame: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "status"
        ]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                if success {
                    self?.log("Status request sent...")
                } else {
                    self?.log("Status request failed")
                }
            }
        }
    }

    // MARK: - Internal send (for outbox drain)

    func sendChatMessage(sessionKey: String, content: String, idempotencyKey: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let frame: [String: Any] = [
                "type": "req",
                "id": UUID().uuidString,
                "method": "chat.send",
                "params": [
                    "sessionKey": sessionKey,
                    "message": content,
                    "idempotencyKey": idempotencyKey
                ]
            ]
            sendJSON(frame) { success in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Cron

    func toggleCron(_ job: CronJob) {
        // TODO: Send cron update via WebSocket
    }

    func runCron(_ job: CronJob) {
        // TODO: Send cron run via WebSocket
    }

    // MARK: - Helpers

    private func sendJSON(_ dict: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let ws = webSocket else {
            logger.warning("sendJSON: no active WebSocket")
            log("Cannot send — no WebSocket connection")
            completion(false)
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else {
            logger.error("sendJSON: serialization failed")
            log("Cannot send — JSON serialization failed")
            completion(false)
            return
        }

        logger.debug("Sending \(text.count) chars")

        ws.send(.string(text)) { error in
            if let error {
                logger.error("WebSocket send error: \(error.localizedDescription, privacy: .public)")
            }
            completion(error == nil)
        }
    }

    func log(_ entry: String) {
        let ts = Self.logDateFormatter.string(from: Date())
        let line = "[\(ts)] \(entry)"
        connectionLog.append(line)
        logger.log("\(entry, privacy: .public)")
        if connectionLog.count > 500 {
            connectionLog.removeFirst(connectionLog.count - 500)
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Persistence (Keychain)

    private func savePairing() {
        guard let url = gatewayURL, let token = authToken else { return }
        KeychainService.save(key: "gatewayURL", value: url.absoluteString)
        KeychainService.save(key: "authToken", value: token)
        logger.info("Pairing saved to Keychain")
        log("Credentials saved to Keychain")
    }

    private func loadPairing() {
        guard let urlString = KeychainService.load(key: "gatewayURL"),
              let token = KeychainService.load(key: "authToken"),
              let url = URL(string: urlString) else {
            logger.debug("No pairing in Keychain")
            return
        }
        gatewayURL = url
        authToken = token
        isPaired = true
        logger.info("Loaded pairing: \(url.absoluteString, privacy: .public)")
    }

    private func clearPairing() {
        KeychainService.delete(key: "gatewayURL")
        KeychainService.delete(key: "authToken")
        logger.info("Pairing cleared from Keychain")
        log("Credentials removed from Keychain")
    }
}
