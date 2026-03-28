import Foundation

struct CronJob: Identifiable, Codable {
    let id: String
    let name: String
    var enabled: Bool
    let schedule: String        // human-readable: "Every day at 08:00"
    let nextRunAt: Date?
    let lastRunAt: Date?
    var lastRunStatus: String?  // "ok", "error"
}
