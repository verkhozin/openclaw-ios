import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "SessionStore")

/// Manages chat sessions and messages with SQLite cache + gateway sync.
/// Publishes reactive state for SwiftUI.
@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessions: [ChatSession] = []
    @Published var currentSessionKey: String = ""
    @Published var currentMessages: [Message] = []

    private let db = ChatDatabase.shared
    private var streamingMessage: Message?  // in-memory only while agent is typing

    private init() {
        loadSessions()
    }

    // MARK: - Sessions

    func loadSessions() {
        sessions = db.allSessions()
        logger.info("Loaded \(self.sessions.count) sessions from cache")
    }

    func ensureSession(key: String, title: String? = nil) {
        if db.session(for: key) == nil {
            let session = ChatSession(
                sessionKey: key,
                title: title ?? key,
                lastMessageAt: Int64(Date().timeIntervalSince1970 * 1000),
                lastMessagePreview: "",
                unreadCount: 0,
                agentId: "",
                model: "",
                cachedUntilSeq: 0
            )
            db.upsertSession(session)
            loadSessions()
        }
    }

    /// Switch to a session: load cached messages, mark read.
    func openSession(key: String) {
        currentSessionKey = key
        ensureSession(key: key)

        // Load from cache
        let cached = db.messages(for: key, limit: 50)
        currentMessages = cached.map { $0.toMessage() }
        streamingMessage = nil

        // Mark as read
        if let lastSeq = cached.last?.seq {
            db.markRead(sessionKey: key, seq: lastSeq)
        }

        loadSessions() // refresh unread counts
        logger.info("Opened session \(key, privacy: .public) with \(cached.count) cached messages")
    }

    // MARK: - Receive messages from gateway

    /// Called when a chat delta/final event arrives.
    func handleChatEvent(sessionKey: String, state: String, text: String, seq: Int64, timestamp: Int64, runId: String?) {
        ensureSession(key: sessionKey)

        if state == "final" {
            // Finalize: persist to SQLite
            let parsed = ContentParser.parse(text)
            let msgId = runId ?? UUID().uuidString

            let cached = CachedMessage(
                id: msgId,
                sessionKey: sessionKey,
                role: "assistant",
                rawContent: text,
                parsedBlocksJSON: parsed.parsedBlocksJSON,
                tagsJSON: parsed.tagsJSON,
                hasCode: parsed.hasCode,
                hasCard: parsed.hasCard,
                cardType: parsed.cardType,
                timestamp: timestamp,
                seq: seq,
                runId: runId
            )
            db.insertMessage(cached)

            let preview = String(text.prefix(80))
            db.updateSessionLastMessage(sessionKey: sessionKey, timestamp: timestamp, preview: preview, seq: seq)

            // Update UI if this is the current session
            if sessionKey == currentSessionKey {
                // Replace streaming message with final
                if streamingMessage != nil {
                    streamingMessage = nil
                    if let last = currentMessages.last, last.role == .agent, last.isStreaming {
                        currentMessages[currentMessages.count - 1].content = text
                        currentMessages[currentMessages.count - 1].isStreaming = false
                    } else {
                        currentMessages.append(cached.toMessage())
                    }
                } else {
                    currentMessages.append(cached.toMessage())
                }
                db.markRead(sessionKey: sessionKey, seq: seq)
            } else {
                // Increment unread for other sessions
                if var session = sessions.first(where: { $0.sessionKey == sessionKey }) {
                    session.unreadCount += 1
                    db.upsertSession(session)
                }
            }

            loadSessions()
            logger.info("Persisted message to \(sessionKey, privacy: .public) seq=\(seq)")

        } else if state == "delta" {
            // Streaming: keep in memory only
            if sessionKey == currentSessionKey {
                if streamingMessage != nil {
                    // Update existing streaming message
                    if let last = currentMessages.last, last.role == .agent, last.isStreaming {
                        currentMessages[currentMessages.count - 1].content = text
                    }
                } else {
                    // Start new streaming message
                    let msg = Message(role: .agent, content: text, isStreaming: true)
                    streamingMessage = msg
                    currentMessages.append(msg)
                }
            }
        }
    }

    // MARK: - Send messages

    /// Persist user message and return params for gateway send.
    func prepareSend(text: String, sessionKey: String) -> (messageId: String, idempotencyKey: String) {
        let msgId = UUID().uuidString
        let idempotencyKey = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let parsed = ContentParser.parse(text)
        let cached = CachedMessage(
            id: msgId,
            sessionKey: sessionKey,
            role: "user",
            rawContent: text,
            parsedBlocksJSON: parsed.parsedBlocksJSON,
            tagsJSON: parsed.tagsJSON,
            hasCode: parsed.hasCode,
            hasCard: parsed.hasCard,
            cardType: parsed.cardType,
            timestamp: now,
            seq: db.lastSeq(for: sessionKey) + 1,
            runId: nil
        )
        db.insertMessage(cached)
        db.updateSessionLastMessage(sessionKey: sessionKey, timestamp: now, preview: String(text.prefix(80)), seq: cached.seq)

        // Add to UI immediately
        if sessionKey == currentSessionKey {
            currentMessages.append(cached.toMessage())
        }

        loadSessions()
        return (msgId, idempotencyKey)
    }

    // MARK: - Offline outbox

    func enqueueOffline(messageId: String, sessionKey: String, content: String, idempotencyKey: String) {
        db.enqueueOutbox(id: messageId, sessionKey: sessionKey, content: content, idempotencyKey: idempotencyKey)
        logger.info("Message queued for offline send")
    }

    func drainOutbox(send: @escaping (String, String, String) async -> Bool) {
        let pending = db.pendingOutbox()
        guard !pending.isEmpty else { return }
        logger.info("Draining outbox: \(pending.count) messages")

        Task {
            for item in pending {
                let success = await send(item.sessionKey, item.content, item.idempotencyKey)
                if success {
                    db.removeFromOutbox(id: item.id)
                    logger.info("Outbox item \(item.id, privacy: .public) sent")
                } else {
                    logger.warning("Outbox item \(item.id, privacy: .public) failed, will retry")
                    break // stop on first failure
                }
            }
        }
    }

    // MARK: - Pagination

    func loadOlderMessages() {
        guard !currentSessionKey.isEmpty else { return }
        let firstSeq = currentMessages.first.flatMap { _ in
            db.messages(for: currentSessionKey, limit: 1).first?.seq
        }
        guard let seq = firstSeq, seq > 1 else { return }

        let older = db.messages(for: currentSessionKey, limit: 20, beforeSeq: seq)
        let olderMessages = older.map { $0.toMessage() }
        currentMessages.insert(contentsOf: olderMessages, at: 0)
        logger.info("Loaded \(older.count) older messages")
    }

    // MARK: - Cleanup

    func cleanupStale() {
        db.cleanupStaleSessions()
        loadSessions()
    }
}
