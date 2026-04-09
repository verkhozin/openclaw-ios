import Foundation

struct GatewayStatus: Codable {
    var isConnected: Bool = false
    var sessionPercent: Double = 0     // 0-100
    var weeklyPercent: Double = 0      // 0-100
    var sessionResetIn: TimeInterval?  // seconds until reset
    var weeklyResetIn: TimeInterval?
    var model: String = "unknown"
    var version: String = "unknown"
    var agentName: String = "Agent"
    var connId: String = ""
    var mainSessionKey: String = ""
    var latencyMs: Int = 0
}

// MARK: - Connection State

/// Authoritative connection state — published by GatewayService.
/// Observers (notification logic, UI) watch this for transitions.
enum ConnectionState: Equatable {
    /// No active connection, not attempting to connect.
    case disconnected
    /// WebSocket opening, waiting for hello-ok handshake.
    case connecting
    /// Fully connected and authenticated.
    case connected
    /// Connection lost, auto-retrying.
    case reconnecting(attempt: Int)

    var isConnected: Bool { self == .connected }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}

// MARK: - Connection Event

/// Discrete event fired on connection state transitions.
/// Subscribe via `GatewayService.connectionEvents` (Combine PassthroughSubject).
struct ConnectionEvent {
    enum Kind: String {
        /// WebSocket connected and handshake completed.
        case connected
        /// Connection dropped (receive error, ping timeout, etc.).
        case disconnected
        /// Starting a reconnect attempt.
        case reconnecting
        /// All reconnect attempts exhausted.
        case gaveUp
    }

    let kind: Kind
    /// Human-readable reason (e.g. "ping timeout", "receive error: ...").
    let reason: String?
    /// Reconnect attempt number (0 for non-reconnect events).
    let attempt: Int
    /// Round-trip latency at time of event (connected events).
    let latencyMs: Int?
    let timestamp: Date

    init(kind: Kind, reason: String? = nil, attempt: Int = 0, latencyMs: Int? = nil) {
        self.kind = kind
        self.reason = reason
        self.attempt = attempt
        self.latencyMs = latencyMs
        self.timestamp = Date()
    }
}
