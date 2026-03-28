import Foundation
import Combine

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
    
    // MARK: - Connection
    private var webSocket: URLSessionWebSocketTask?
    private var gatewayURL: URL?
    private var authToken: String?
    
    private init() {
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
        disconnect()
        gatewayURL = nil
        authToken = nil
        clearPairing()
        isPaired = false
    }
    
    // MARK: - WebSocket
    
    func connect() {
        guard let url = gatewayURL, let token = authToken else { return }
        
        // TODO: Implement WebSocket connection
        // 1. Open URLSessionWebSocketTask to ws://url
        // 2. Send connect frame with role: "operator", auth: { token }
        // 3. Start receive loop
        // 4. Update status.isConnected
        
        status.isConnected = false // placeholder
    }
    
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        status.isConnected = false
    }
    
    // MARK: - Send message to agent
    
    func sendMessage(_ text: String) {
        let message = Message(role: .user, content: text)
        messages.append(message)
        
        // TODO: Send req:agent frame via WebSocket
        // Gateway will stream event:agent frames back
    }
    
    // MARK: - Cron
    
    func toggleCron(_ job: CronJob) {
        // TODO: Send cron update via WebSocket
    }
    
    func runCron(_ job: CronJob) {
        // TODO: Send cron run via WebSocket
    }
    
    // MARK: - Persistence (Keychain)
    
    private func savePairing() {
        // TODO: Save gatewayURL + authToken to Keychain
    }
    
    private func loadPairing() {
        // TODO: Load from Keychain, set isPaired
    }
    
    private func clearPairing() {
        // TODO: Remove from Keychain
    }
}
