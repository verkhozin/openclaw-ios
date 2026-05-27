import Foundation
import Combine
import Network
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "GatewayService")

enum GatewayRequestError: LocalizedError {
    case sendFailed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .sendFailed: return "Failed to send request"
        case .serverError(let msg): return msg
        }
    }
}

/// Main service: WebSocket connection to OpenClaw Gateway
/// All data flows through here.
@MainActor
class GatewayService: ObservableObject {
    static let shared = GatewayService()

    // MARK: - Published state
    @Published var isPaired: Bool = false
    @Published var isVerifyingConnection: Bool = false
    @Published var connectionError: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var status: GatewayStatus = GatewayStatus()
    @Published var tasks: [AgentTask] = []
    @Published var cronJobs: [CronJob] = []
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var connectionLog: [String] = []
    /// Per-message errors keyed by message ID string (matches Message.id UUID string).
    @Published var messageErrors: [String: String] = [:]

    /// Discrete connection events — subscribe for notification triggers.
    let connectionEvents = PassthroughSubject<ConnectionEvent, Never>()

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
    /// Incremented on every connect() — stale callbacks from old sockets check this.
    nonisolated(unsafe) private var connectionGeneration: Int = 0

    // Network reachability — detects wifi/cellular loss instantly
    private let networkMonitor = NWPathMonitor()
    private var networkWasUnsatisfied = false

    /// Pending request continuations keyed by request ID.
    private var pendingRequests: [String: CheckedContinuation<[String: Any], any Error>] = [:]

    /// Sessions that have already received the system-event (card capability prompt).
    private var sentSystemEventSessions: Set<String> = []

    private var connectionEventSub: AnyCancellable?
    private var sessionStoreSub: AnyCancellable?

    private init() {
        logger.info("GatewayService init")
        // Forward SessionStore changes so views observing GatewayService re-render
        sessionStoreSub = sessionStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        loadPairing()
        observeConnectionEvents()
        startNetworkMonitor()
        if isPaired {
            logger.info("Restored pairing from Keychain — url=\(self.gatewayURL?.absoluteString ?? "nil", privacy: .public)")
            log("Restored pairing from Keychain")
            connect()
        } else {
            logger.info("No saved pairing found")
        }
    }

    // MARK: - Network reachability

    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                if path.status == .unsatisfied || path.status == .requiresConnection {
                    // Network went down
                    if self.status.isConnected {
                        logger.warning("Network path unsatisfied — connection will drop")
                        self.log("Network lost — disconnecting")
                        self.status.isConnected = false
                        self.stopPingTimer()
                        self.networkWasUnsatisfied = true
                        self.scheduleReconnect(reason: "network lost")
                    }
                } else if path.status == .satisfied && self.networkWasUnsatisfied {
                    // Network came back — reconnect immediately if paired
                    self.networkWasUnsatisfied = false
                    if self.isPaired && !self.status.isConnected && !self.isVerifyingConnection {
                        logger.info("Network restored — reconnecting immediately")
                        self.log("Network restored — reconnecting")
                        self.connect()
                    }
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.clios.networkMonitor"))
    }

    // MARK: - Connection → Notification bridge

    /// True only after a disconnect has been shown — gates "connected" notification.
    private var hadDisconnect = false

    private func observeConnectionEvents() {
        connectionEventSub = connectionEvents.sink { [weak self] event in
            guard let self, self.isPaired else { return }

            switch event.kind {
            case .disconnected:
                hadDisconnect = true
                NotificationManager.shared.post(AppNotification(
                    type: .connectionLost,
                    style: .island,
                    title: "Gateway disconnected",
                    subtitle: event.reason
                ))

            case .reconnecting:
                break

            case .connected:
                // Only show if recovering from a prior disconnect
                guard hadDisconnect else { return }
                hadDisconnect = false
                let subtitle = event.latencyMs.map { "\($0)ms" }
                NotificationManager.shared.post(AppNotification(
                    type: .connectionRestored,
                    style: .island,
                    title: "Connected",
                    subtitle: subtitle
                ))

            case .gaveUp:
                NotificationManager.shared.post(AppNotification(
                    type: .connectionLost,
                    style: .island,
                    title: "Connection failed",
                    subtitle: "Could not reconnect after \(event.attempt) attempts"
                ))
            }
        }
    }

    // MARK: - Pairing

    func pair(url: URL, token: String) {
        logger.info("Pairing with \(url.absoluteString, privacy: .public)")
        log("Pairing with \(url.absoluteString)")
        gatewayURL = url
        authToken = token
        connectionError = nil
        isVerifyingConnection = true
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
        connectionState = .disconnected
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
        connectionGeneration += 1
        connectionState = .connecting

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
        EntityIndex.shared.stopPeriodicReindex()
        if webSocket != nil {
            logger.info("Disconnecting WebSocket")
            log("Closing WebSocket connection")
        }
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session = nil
        status.isConnected = false
        sentSystemEventSessions.removeAll()
        if connectionState.isConnected {
            connectionState = .disconnected
        }
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
                "scopes": ["operator.read", "operator.write", "operator.approvals", "operator.pairing", "operator.admin"],
                "caps": ["cards.v1", "skill"],
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
                    self.scheduleReconnect(reason: "connect req failed")
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

    private func scheduleReconnect(reason: String? = nil) {
        // During initial verification, fail immediately — don't auto-retry
        if isVerifyingConnection {
            logger.error("Connection failed during verification — aborting pairing")
            log("Connection failed — could not verify gateway")
            isVerifyingConnection = false
            connectionError = "Could not connect to gateway. Check the address and token."
            connectionState = .disconnected
            connectionEvents.send(ConnectionEvent(kind: .disconnected, reason: reason ?? "verification failed"))
            disconnect()
            return
        }

        // Fire disconnected event on first attempt (transition from connected)
        if reconnectAttempt == 0 {
            connectionEvents.send(ConnectionEvent(kind: .disconnected, reason: reason))
        }

        reconnectAttempt += 1
        guard reconnectAttempt <= maxReconnectAttempts else {
            logger.error("Max reconnect attempts (\(self.maxReconnectAttempts)) reached — giving up")
            log("Max reconnect attempts reached — giving up. Tap Connect to retry.")
            connectionState = .disconnected
            connectionEvents.send(ConnectionEvent(kind: .gaveUp, reason: "max attempts reached", attempt: reconnectAttempt - 1))
            return
        }

        connectionState = .reconnecting(attempt: reconnectAttempt)
        connectionEvents.send(ConnectionEvent(kind: .reconnecting, reason: reason, attempt: reconnectAttempt))

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
        logger.debug("Starting ping timer (every 10s)")
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendProtocolPing()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private var pingTimeoutTask: Task<Void, Never>?

    private func sendProtocolPing() {
        guard let ws = webSocket else { return }
        let gen = connectionGeneration
        let sendTime = ContinuousClock.now
        // Timeout: if pong doesn't arrive in 5s, treat as dead
        pingTimeoutTask?.cancel()
        pingTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self,
                  gen == self.connectionGeneration,
                  self.status.isConnected else { return }
            logger.warning("Ping pong timeout (5s) — connection dead")
            self.log("Ping timeout — no pong in 5s")
            self.status.isConnected = false
            self.stopPingTimer()
            self.scheduleReconnect(reason: "ping timeout")
        }

        ws.sendPing { [weak self] error in
            guard gen == self?.connectionGeneration else { return }
            let elapsed = ContinuousClock.now - sendTime
            let ms = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
            Task { @MainActor in
                guard let self, gen == self.connectionGeneration else { return }
                self.pingTimeoutTask?.cancel()
                if let error {
                    logger.warning("Protocol ping failed: \(error.localizedDescription, privacy: .public)")
                    self.log("Keepalive ping failed: \(error.localizedDescription)")
                    self.status.isConnected = false
                    self.scheduleReconnect(reason: "ping failed")
                } else {
                    logger.debug("Protocol ping OK — \(ms)ms")
                    self.status.latencyMs = ms
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

        let gen = connectionGeneration
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
                // Ignore errors from old (cancelled) sockets
                guard gen == self.connectionGeneration else { return }
                let nsError = error as NSError
                logger.error("WebSocket receive error: \(error.localizedDescription, privacy: .public) (code: \(nsError.code))")
                Task { @MainActor in
                    self.log("Connection lost: \(error.localizedDescription) [code \(nsError.code)]")
                    self.status.isConnected = false
                    self.stopPingTimer()
                    self.scheduleReconnect(reason: error.localizedDescription)
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
            self.status.latencyMs = Int(latency)
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
            connectionState = .connected
            connectionEvents.send(ConnectionEvent(kind: .connected, latencyMs: status.latencyMs))
            reconnectAttempt = 0
            startPingTimer()

            // Finalize pairing on first successful connection
            if isVerifyingConnection {
                savePairing()
                isPaired = true
                isVerifyingConnection = false
                connectionError = nil
                logger.info("Connection verified via event — pairing confirmed")
                log("Connection verified — pairing saved")
            }

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
            let rawSessionKey = src["sessionKey"] as? String ?? ""
            let resolvedKey = rawSessionKey.isEmpty
                ? (sessionStore.currentSessionKey.isEmpty ? status.mainSessionKey : sessionStore.currentSessionKey)
                : rawSessionKey
            let sessionKey = sessionStore.resolveSessionKey(resolvedKey)
            let seq = (src["seq"] as? Int64) ?? Int64(src["seq"] as? Int ?? 0)
            let msg = src["message"] as? [String: Any]
            let contentArr = msg?["content"] as? [[String: Any]]
            // Concatenate all text content blocks — cards may be in any block
            let text = contentArr?
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n") ?? ""
            let ts = (msg?["timestamp"] as? Int64) ?? Int64(Date().timeIntervalSince1970 * 1000)
            let runId = src["runId"] as? String

            let isActiveSession = sessionKey == sessionStore.currentSessionKey
            logger.info("Chat event: state=\(state, privacy: .public) sessionKey=\(sessionKey, privacy: .public) textLen=\(text.count)")
            if state == "final" || state == "delta" {
                log("CHAT \(state) session=\(sessionKey) active=\(isActiveSession) current=\(sessionStore.currentSessionKey) seq=\(seq)")
            }
            if !text.isEmpty {
                sessionStore.handleChatEvent(
                    sessionKey: sessionKey,
                    state: state,
                    text: text,
                    seq: seq,
                    timestamp: ts,
                    runId: runId
                )
                if state == "final" {
                    log("Agent response complete (\(text.count) chars)")
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
            // Reindex tasks on task events
            Task { await EntityIndex.shared.reindex(type: .task) }

        case "calendar", "event:calendar":
            let src = json["payload"] as? [String: Any] ?? json
            handleCalendarEvent(src)

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
        let reqId = json["id"] as? String
        let ok = json["ok"] as? Bool ?? false

        // Debug: log all non-hello-ok responses so we can see system-event results
        if payloadType != "hello-ok" {
            if let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? "?"
                let code = error["code"] as? String ?? error["code"].flatMap { "\($0)" } ?? ""
                log("RES id=\(reqId.map { String($0.prefix(8)) } ?? "?")... ok=\(ok) error=\(code) \(msg)")
            } else if reqId != nil {
                log("RES id=\(reqId!.prefix(8))... ok=\(ok) type=\(payloadType ?? "nil")")
            }
        }

        // Dispatch to pending continuation if one exists
        if let reqId, let continuation = pendingRequests.removeValue(forKey: reqId) {
            if let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? "Unknown error"
                continuation.resume(throwing: GatewayRequestError.serverError(msg))
            } else {
                continuation.resume(returning: payload)
            }
            return
        }

        if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "Unknown error"
            let code = error["code"] as? String ?? error["code"].flatMap { "\($0)" }
            log("Response error: \(msg)\(code.map { " [\($0)]" } ?? "")")

            // If verifying, surface the error and abort
            if isVerifyingConnection {
                isVerifyingConnection = false
                connectionError = msg
                disconnect()
            } else if let reqId {
                messageErrors[reqId] = msg
            }
            return
        }

        if ok && payloadType == "hello-ok" {
            let server = payload["server"] as? [String: Any] ?? [:]
            let version = server["version"] as? String ?? "unknown"
            let connId = server["connId"] as? String ?? ""

            log("Connected to gateway!")
            log("  server: v\(version)")
            log("  connId: \(connId.prefix(12))...")

            // Debug: log auth scopes and caps from hello-ok
            let auth = payload["auth"] as? [String: Any] ?? [:]
            let scopes = auth["scopes"] as? [String] ?? []
            let caps = auth["caps"] as? [String] ?? payload["caps"] as? [String] ?? []
            log("  scopes: \(scopes.joined(separator: ", "))")
            log("  caps: \(caps.isEmpty ? "(none)" : caps.joined(separator: ", "))")
            status.isConnected = true
            status.version = version
            status.connId = connId
            connectionState = .connected
            connectionEvents.send(ConnectionEvent(kind: .connected, latencyMs: status.latencyMs))

            // Finalize pairing on first successful connection
            if isVerifyingConnection {
                savePairing()
                isPaired = true
                isVerifyingConnection = false
                connectionError = nil
                logger.info("Connection verified — pairing confirmed")
                log("Connection verified — pairing saved")
            }

            // Extract mainSessionKey from snapshot
            let snapshot = payload["snapshot"] as? [String: Any] ?? [:]
            let sessionDefaults = snapshot["sessionDefaults"] as? [String: Any] ?? [:]
            if let mainKey = sessionDefaults["mainSessionKey"] as? String {
                status.mainSessionKey = mainKey
                log("  sessionKey: \(mainKey)")

                // Initialize session in store; only open if user isn't already in a session
                sessionStore.ensureSession(key: mainKey, title: "Main")
                if sessionStore.currentSessionKey.isEmpty {
                    sessionStore.openSession(key: mainKey)
                }

                // Caps will be prepended to the first message in each session
            }

            // Drain offline outbox
            sessionStore.drainOutbox { [weak self] sessionKey, content, idempotencyKey in
                await (self?.sendChatMessage(sessionKey: sessionKey, content: content, idempotencyKey: idempotencyKey) ?? false)
            }
            reconnectAttempt = 0
            startPingTimer()

            // Sync sessions and history from gateway
            Task { [weak self] in
                await self?.syncSessions()
                // Re-fetch history for current session to catch messages missed while offline
                let currentKey = self?.sessionStore.currentSessionKey ?? ""
                if !currentKey.isEmpty {
                    await self?.fetchHistory(sessionKey: currentKey)
                }
                // Load project→session mapping from workspace
                await self?.sessionStore.loadSessionMapping()
            }

            // Start entity indexing on successful connection
            setupEntityIndex()
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
        // Resolve the session this event belongs to.
        // Priority: event.sessionKey → currentSessionKey → mainSessionKey
        // Gateway wraps keys as agent:*:uuid — resolve back to local session key.
        let eventSessionKey: String = {
            if !event.sessionKey.isEmpty {
                return sessionStore.resolveSessionKey(event.sessionKey)
            }
            if !sessionStore.currentSessionKey.isEmpty { return sessionStore.currentSessionKey }
            return status.mainSessionKey
        }()

        let isActive = eventSessionKey == sessionStore.currentSessionKey
        log("AGENT \(event.stream.logLabel) session=\(eventSessionKey) active=\(isActive) current=\(sessionStore.currentSessionKey)")

        switch event.stream {
        case .lifecycleStart:
            activeRunId = event.runId
            logger.info("Agent run started: \(event.runId.prefix(12)) session=\(eventSessionKey, privacy: .public)")
            // Only insert streaming placeholder if this is the active session
            if eventSessionKey == sessionStore.currentSessionKey {
                sessionStore.beginAgentResponse(sessionKey: eventSessionKey)
            }

        case .assistant(let text, _):
            // Only update streaming UI if this is the active session
            if eventSessionKey == sessionStore.currentSessionKey {
                if let idx = sessionStore.currentMessages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                    sessionStore.currentMessages[idx].content = text
                }
            }

        case .lifecycleEnd:
            logger.info("Agent run ended: \(event.runId.prefix(12)) session=\(eventSessionKey, privacy: .public)")
            log("Agent finished (run: \(event.runId.prefix(12))...)")
            // Finalize only if this is the active session
            if eventSessionKey == sessionStore.currentSessionKey {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms grace
                    self?.sessionStore.finalizeAgentResponse()
                }
            }
            activeRunId = nil
        }
    }

    // MARK: - Handle calendar events

    private func handleCalendarEvent(_ payload: [String: Any]) {
        let action = payload["action"] as? String ?? "sync"

        switch action {
        case "sync", "list":
            // Full list replace from gateway
            guard let items = payload["events"] as? [[String: Any]] else {
                log("Calendar sync: no events array")
                return
            }
            let decoded = items.compactMap { Self.decodeCalendarEvent($0) }
            calendarEvents = decoded
            log("Calendar sync: \(decoded.count) events")
            Task { await EntityIndex.shared.reindex(type: .event) }

        case "upsert":
            // Single event created or updated
            guard let item = payload["event"] as? [String: Any],
                  let event = Self.decodeCalendarEvent(item) else { break }
            if let idx = calendarEvents.firstIndex(where: { $0.id == event.id }) {
                calendarEvents[idx] = event
            } else {
                calendarEvents.append(event)
            }
            log("Calendar upsert: \(event.title)")
            Task { await EntityIndex.shared.reindex(type: .event) }

        case "delete":
            guard let eventId = payload["eventId"] as? String else { break }
            calendarEvents.removeAll { $0.id == eventId }
            log("Calendar delete: \(eventId)")
            EntityIndex.shared.remove(ids: ["event:\(eventId)"])

        default:
            log("Calendar: unhandled action '\(action)'")
        }
    }

    private static func decodeCalendarEvent(_ dict: [String: Any]) -> CalendarEvent? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let startRaw = dict["startDate"] as? String,
              let endRaw = dict["endDate"] as? String else {
            return nil
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Fallback without fractional seconds
        let fmtAlt = ISO8601DateFormatter()

        guard let start = fmt.date(from: startRaw) ?? fmtAlt.date(from: startRaw),
              let end = fmt.date(from: endRaw) ?? fmtAlt.date(from: endRaw) else {
            return nil
        }

        let sourceStr = dict["source"] as? String ?? "agent"
        let statusStr = dict["status"] as? String ?? "confirmed"

        var attendees: [CalendarEvent.Attendee] = []
        if let list = dict["attendees"] as? [[String: Any]] {
            attendees = list.map { a in
                CalendarEvent.Attendee(
                    name: a["name"] as? String ?? "",
                    email: a["email"] as? String,
                    rsvp: a["rsvp"] as? String
                )
            }
        }

        var recurrence: CalendarEvent.RecurrenceRule? = nil
        if let r = dict["recurrence"] as? [String: Any],
           let freqStr = r["frequency"] as? String,
           let freq = CalendarEvent.RecurrenceRule.Frequency(rawValue: freqStr) {
            recurrence = CalendarEvent.RecurrenceRule(
                frequency: freq,
                interval: r["interval"] as? Int ?? 1,
                until: (r["until"] as? String).flatMap { fmt.date(from: $0) ?? fmtAlt.date(from: $0) },
                count: r["count"] as? Int,
                daysOfWeek: r["daysOfWeek"] as? [Int]
            )
        }

        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: dict["isAllDay"] as? Bool ?? false,
            source: CalendarEvent.Source(rawValue: sourceStr) ?? .agent,
            sourceId: dict["sourceId"] as? String,
            location: dict["location"] as? String,
            notes: dict["notes"] as? String,
            attendees: attendees,
            status: CalendarEvent.Status(rawValue: statusStr) ?? .confirmed,
            recurrence: recurrence,
            color: dict["color"] as? String
        )
    }

    // MARK: - Send message to agent

    // MARK: - System event (notify agent of client capabilities)

    // MARK: - Card capability instruction for agent

    private static let cardCapabilityPrompt = """
    [SYSTEM] CLiOS mobile client connected (platform: iOS, client: clios).
    The user is writing from the CLiOS native iOS app — NOT webchat, NOT Telegram, NOT Discord.
    This session supports rich cards (cards.v1) and skills.

    IMPORTANT: When outputting structured data, you MUST use card codeblocks instead of plain text.

    ## Format
    Standard markdown codeblock with `card:type` as language, key: value pairs inside:

    ```card:github.pr
    title: Fix hero animation
    status: merged
    repo: verkh-tech/site
    ci: passed
    additions: 42
    deletions: 8
    ```

    For actions (user approval needed), add `---` separator:
    ```card:email.draft
    to: alex@example.com
    subject: Proposal
    content: Hi Alex...
    ---
    actions: approve, edit, discard
    ```

    ## Available card types
    - github.pr — PRs (fields: number, title, status, author, repo, branch, targetBranch, ci, additions, deletions)
    - github.issue — issues (fields: title, labels, assignee, status)
    - github.ci — CI/CD (fields: status, duration, logs)
    - email.inbox — incoming email (fields: from, subject, content, time, isUnread)
    - email.draft — composed email (fields: to, subject, content; actions: approve, edit, discard)
    - email.digest — multiple emails summary (fields: count, urgent, from, subject)
    - calendar.event — meetings (fields: title, date, startTime, endTime, duration, location, attendees)
    - calendar.conflict — overlapping events (fields: event1, event2, suggestion)
    - linear.issue — task tracker (fields: source, id, title, status, priority, assignee, labels, project)
    - file.preview — saved files (fields: path, type, size, url)
    - file.diff — code changes (fields: path, additions, deletions, summary)
    - lead — CRM/sales (fields: name, round, site, status, contact)
    - task.status — subagent status (fields: id, label, status, model, runtime, tokens)
    - task.approval — permission request (fields: id, command, risk, context; actions: approve, deny)
    - todo — checklist (fields: title, items as "text|done" comma-separated, updated)
    - digest.morning — morning briefing (fields: date, greeting, calendar, email, tasks, summary)
    - story — notable event (fields: title, body, action, action_target)
    - session.title — name this chat session, 3-5 words (fields: title). Send as FIRST reply in new sessions.

    ## Mentions
    User messages may contain inline mentions in the format: @[type:entityId:displayName]
    Examples:
    - @[task:clios-015:Fix input auto-resize] — reference to a task
    - @[file:src/App.swift:App.swift] — reference to a workspace file
    - @[session:abc123:Design Chat] — reference to a chat session
    - @[agent:code:CodeAgent] — reference to an agent

    When you see a mention:
    1. Treat `type` as the entity kind (task, file, session, agent, cron, branch).
    2. Use `entityId` to look up context — read the file, check the task board, etc.
    3. In your replies, use the same @[type:id:name] format to reference entities — the app renders them as tappable chips.

    ## Rules
    1. One type per situation — type follows from context.
    2. Digest over spam — multiple similar items → one digest card, NOT separate cards.
    3. If no type fits, use plain text.
    4. Always use cards when structured data is available — the mobile app renders them as native UI components.
    5. ALWAYS include a `session.title` card in your FIRST reply in any new session. Name the chat based on the user's first message, 3-5 words. Example:
       ```card:session.title
       title: Debug auth token refresh
       ```
    """

    private func sendSystemEvent(sessionKey: String) {
        // Try system-event first (requires operator.admin, only targets main session).
        // If it fails, fall back to chat.send which works for any session.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let _ = try await self.sendRequest(method: "system-event", params: [
                    "text": Self.cardCapabilityPrompt,
                    "sessionKey": sessionKey
                ])
                self.log("system-event OK for session=\(sessionKey)")
            } catch {
                self.log("system-event FAILED: \(error.localizedDescription) — falling back to chat.send")
                self.sendCapabilityViaChatSend(sessionKey: sessionKey)
            }
        }
    }

    private func sendCapabilityViaChatSend(sessionKey: String) {
        let capsMessage = "[SYSTEM] " + Self.cardCapabilityPrompt
        let idempotencyKey = "caps-\(sessionKey)-\(UUID().uuidString.prefix(8))"
        let frame: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "chat.send",
            "params": [
                "sessionKey": sessionKey,
                "message": capsMessage,
                "idempotencyKey": idempotencyKey
            ]
        ]
        log("OUT chat.send (caps fallback) session=\(sessionKey)")
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                if success {
                    self?.log("Caps fallback delivered via chat.send")
                } else {
                    self?.log("Caps fallback via chat.send FAILED")
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
        log("OUT chat.send → session=\(sessionKey) (current=\(sessionStore.currentSessionKey), main=\(status.mainSessionKey))")

        // Prepend card capability prompt (+ project context if applicable) to the first message in new sessions
        var messageText = text
        if !sentSystemEventSessions.contains(sessionKey) {
            var preamble = Self.cardCapabilityPrompt
            if let projectContext = buildProjectContext(for: sessionKey) {
                preamble += "\n\n" + projectContext
            }
            messageText = preamble + "\n\n---\n\n" + text
            sentSystemEventSessions.insert(sessionKey)
            log("Prepended caps prompt to first message in session=\(sessionKey)")
        }

        let prepared = sessionStore.prepareSend(text: text, sessionKey: sessionKey)

        let params: [String: Any] = [
            "sessionKey": sessionKey,
            "message": messageText,
            "idempotencyKey": prepared.idempotencyKey,
        ]

        let frame: [String: Any] = [
            "type": "req",
            "id": prepared.messageId,
            "method": "chat.send",
            "params": params,
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

    /// Resend a previously failed message (same text, new request ID, no new UI message).
    func resendMessage(_ text: String, originalId: String) {
        messageErrors.removeValue(forKey: originalId)

        let sessionKey = sessionStore.currentSessionKey.isEmpty
            ? status.mainSessionKey
            : sessionStore.currentSessionKey
        log("OUT chat.send (resend) session=\(sessionKey)")

        let newId = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req",
            "id": newId,
            "method": "chat.send",
            "params": [
                "sessionKey": sessionKey,
                "message": text,
                "idempotencyKey": UUID().uuidString,
            ] as [String: Any],
        ]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                if !success {
                    self?.messageErrors[originalId] = "Failed to send"
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

    /// Send a slash command without creating a visible user message.
    func sendCommand(_ command: String) {
        let sessionKey = sessionStore.currentSessionKey.isEmpty
            ? status.mainSessionKey
            : sessionStore.currentSessionKey
        log("OUT command → \(command) session=\(sessionKey)")
        let frame: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "chat.send",
            "params": [
                "sessionKey": sessionKey,
                "message": command,
                "idempotencyKey": UUID().uuidString,
            ],
        ]
        sendJSON(frame) { [weak self] success in
            Task { @MainActor in
                self?.log("Command \(command): \(success ? "delivered" : "FAILED")")
            }
        }
    }

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

    // MARK: - Request / Response

    /// Send a WebSocket request and await the response payload.
    func sendRequest(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let reqId = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req",
            "id": reqId,
            "method": method,
            "params": params
        ]

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[reqId] = continuation
            sendJSON(frame) { [weak self] success in
                Task { @MainActor in
                    if !success {
                        self?.pendingRequests.removeValue(forKey: reqId)
                        continuation.resume(throwing: GatewayRequestError.sendFailed)
                    }
                }
            }
        }
    }

    // MARK: - History sync

    /// Fetch message history from gateway for a session and ingest into local cache.
    func fetchHistory(sessionKey: String, limit: Int = 200) async {
        guard status.isConnected else { return }
        do {
            let payload = try await sendRequest(method: "chat.history", params: [
                "sessionKey": sessionKey,
                "limit": limit
            ])
            guard let messages = payload["messages"] as? [[String: Any]] else {
                log("chat.history: no messages in response")
                return
            }
            sessionStore.ingestHistory(sessionKey: sessionKey, rawMessages: messages)
            log("Fetched \(messages.count) history messages for \(sessionKey)")
        } catch {
            log("chat.history failed: \(error.localizedDescription)")
        }
    }

    /// Fetch session list from gateway and merge into local cache.
    func syncSessions() async {
        guard status.isConnected else { return }
        do {
            let payload = try await sendRequest(method: "sessions.list", params: [
                "limit": 50,
                "includeDerivedTitles": true,
                "includeLastMessage": true
            ] as [String: Any])
            guard let sessions = payload["sessions"] as? [[String: Any]] else {
                log("sessions.list: no sessions in response")
                return
            }
            sessionStore.mergeSessions(from: sessions)
            log("Synced \(sessions.count) sessions from gateway")
        } catch {
            log("sessions.list failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Entity Index

    private var entityIndexConfigured = false

    /// Register entity providers and kick off initial index.
    private func setupEntityIndex() {
        guard !entityIndexConfigured else {
            // Already configured — just trigger a reindex
            Task { await EntityIndex.shared.reindexAll() }
            return
        }
        entityIndexConfigured = true

        let index = EntityIndex.shared
        index.register(provider: FileEntityProvider(), for: .file)
        index.register(provider: TaskEntityProvider(), for: .task)
        index.register(provider: SessionEntityProvider(), for: .session)
        index.register(provider: AgentEntityProvider(), for: .agent)
        index.register(provider: CronEntityProvider(), for: .cron)
        index.register(provider: CalendarEventEntityProvider(), for: .event)
        index.register(provider: ProjectEntityProvider(), for: .project)
        index.startPeriodicReindex()

        Task { await index.reindexAll() }
        logger.info("Entity index configured and initial reindex started")
    }

    // MARK: - Project Context

    /// Build project context string for a session, if it belongs to a project.
    private func buildProjectContext(for sessionKey: String) -> String? {
        guard let projectId = sessionStore.projectId(for: sessionKey) else { return nil }
        // Use cached mapping — project name/description will be fetched async on first use.
        // For now, include the essential info the agent needs: project id and paths.
        return """
        [PROJECT CONTEXT]
        You are working inside project "\(projectId)".
        - Working directory: workspace/projects/\(projectId)/
        - Tasks: workspace/projects/\(projectId)/tasks/
        - Files: workspace/projects/\(projectId)/files/
        - All file operations for this project should use this working directory.
        - Read workspace/projects/\(projectId)/project.json for project name and description.
        """
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
