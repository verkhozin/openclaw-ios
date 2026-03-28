import Foundation

struct AgentTask: Identifiable, Codable {
    let id: String              // runId from Gateway
    let sessionKey: String
    let label: String
    let task: String            // first line of task description
    var status: Status
    let model: String
    let startedAt: Date
    var endedAt: Date?
    var totalTokens: Int?
    
    enum Status: String, Codable {
        case running
        case done
        case failed
        case killed
    }
    
    var runtime: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }
    
    var runtimeFormatted: String {
        let mins = Int(runtime / 60)
        let secs = Int(runtime.truncatingRemainder(dividingBy: 60))
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
