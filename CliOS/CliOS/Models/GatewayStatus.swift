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
}
