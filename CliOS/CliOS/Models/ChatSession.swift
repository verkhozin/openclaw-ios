import Foundation

/// A cached chat session (maps to SQLite sessions table).
struct ChatSession: Identifiable {
    var id: String { sessionKey }

    let sessionKey: String
    var title: String
    var lastMessageAt: Int64       // ms timestamp
    var lastMessagePreview: String
    var unreadCount: Int
    var agentId: String
    var model: String
    var cachedUntilSeq: Int64
}
