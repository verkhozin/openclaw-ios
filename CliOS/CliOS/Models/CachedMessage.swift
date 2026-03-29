import Foundation

/// A message persisted in SQLite (cache of gateway data + parsed content).
struct CachedMessage: Identifiable {
    let id: String
    let sessionKey: String
    let role: String               // "user", "assistant", "system"
    let rawContent: String
    var parsedBlocksJSON: String?   // JSON-encoded [ContentBlock] for fast render
    var tagsJSON: String?           // JSON array: ["code", "swift", "card:github.pr"]
    var hasCode: Bool
    var hasCard: Bool
    var cardType: String?
    let timestamp: Int64            // ms
    var seq: Int64                  // gateway sequence number for sync
    var runId: String?

    /// Convert to in-memory Message for UI display.
    func toMessage() -> Message {
        let messageRole: Message.Role
        switch role {
        case "user": messageRole = .user
        case "system": messageRole = .system
        default: messageRole = .agent
        }

        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            role: messageRole,
            content: rawContent,
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000),
            isStreaming: false
        )
    }

    /// Tags as array.
    var tags: [String] {
        guard let json = tagsJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }
}
