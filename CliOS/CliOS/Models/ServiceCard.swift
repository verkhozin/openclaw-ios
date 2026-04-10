import Foundation

/// Structured card parsed from agent output
struct ServiceCard: Identifiable, Codable {
    let id: UUID
    let type: CardType
    let fields: [String: String]
    
    enum CardType: String, Codable {
        // GitHub
        case githubPR = "github.pr"
        case githubIssue = "github.issue"
        case githubCI = "github.ci"
        // Email
        case emailInbox = "email.inbox"
        case emailDraft = "email.draft"
        case emailDigest = "email.digest"
        // Calendar
        case calendarEvent = "calendar.event"
        case calendarConflict = "calendar.conflict"
        // Linear
        case linearIssue = "linear.issue"
        // Files
        case filePreview = "file.preview"
        case fileDiff = "file.diff"
        // Lead pipeline
        case lead = "lead"
        // Todo
        case todo = "todo"
        // Session
        case sessionTitle = "session.title"
        // Notifications
        case notify = "notify"
        case notifyGit = "notify.git"
        case notifyWorkflow = "notify.workflow"
        case notifySubagent = "notify.subagent"
        // Generic
        case unknown
    }
    
    init(id: UUID = UUID(), type: CardType, fields: [String: String]) {
        self.id = id
        self.type = type
        self.fields = fields
    }
}
