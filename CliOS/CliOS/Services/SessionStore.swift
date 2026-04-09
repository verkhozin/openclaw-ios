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
                title: title ?? Self.readableTitle(from: key),
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
    /// If already viewing this session, just refreshes from DB without losing streaming state.
    func openSession(key: String) {
        let isSameSession = currentSessionKey == key
        currentSessionKey = key
        ensureSession(key: key)

        // Load from cache
        let cached = db.messages(for: key, limit: 50)

        if isSameSession && streamingMessage != nil {
            // Don't clobber in-progress streaming — just merge any new persisted messages
            let existingIDs = Set(currentMessages.map(\.id))
            let newMessages = cached.map { $0.toMessage() }.filter { !existingIDs.contains($0.id) }
            if !newMessages.isEmpty {
                // Insert at correct positions (before streaming message)
                let streamIdx = currentMessages.lastIndex(where: { $0.isStreaming }) ?? currentMessages.endIndex
                currentMessages.insert(contentsOf: newMessages, at: streamIdx)
            }
        } else {
            currentMessages = cached.map { $0.toMessage() }
            streamingMessage = nil
        }

        // Rebuild seenSeqs from loaded messages to prevent dupes on reconnect
        seenSeqs = Set(cached.compactMap { $0.seq > 0 ? $0.seq : nil })

        // Mark as read
        if let lastSeq = cached.last?.seq {
            db.markRead(sessionKey: key, seq: lastSeq)
        }

        loadSessions()
        logger.info("Opened session \(key, privacy: .public) with \(cached.count) cached messages (same=\(isSameSession))")
    }

    // MARK: - Receive messages from gateway

    /// Track seen seq numbers to prevent duplicates from reconnects
    private var seenSeqs: Set<Int64> = []

    /// Called when a chat delta/final event arrives.
    func handleChatEvent(sessionKey: String, state: String, text: String, seq: Int64, timestamp: Int64, runId: String?) {
        ensureSession(key: sessionKey)

        if state == "final" {
            // Dedup: skip if we already processed this seq for this session
            if seq > 0 && seenSeqs.contains(seq) {
                logger.info("Skipping duplicate final seq=\(seq)")
                return
            }
            if seq > 0 { seenSeqs.insert(seq) }

            // Persist to SQLite (INSERT OR REPLACE handles DB-level dedup by id)
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

            let preview = Self.generatePreview(from: text)
            db.updateSessionLastMessage(sessionKey: sessionKey, timestamp: timestamp, preview: preview, seq: seq)

            if sessionKey == currentSessionKey {
                // Replace streaming message with final
                if streamingMessage != nil {
                    streamingMessage = nil
                    if let idx = currentMessages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                        currentMessages[idx].content = text
                        currentMessages[idx].isStreaming = false
                    } else {
                        currentMessages.append(cached.toMessage())
                    }
                } else {
                    let alreadyHave = seq > 0 && currentMessages.contains(where: { msg in
                        msg.role == .agent && msg.content == text && !msg.isStreaming
                    })
                    if !alreadyHave {
                        currentMessages.append(cached.toMessage())
                    }
                }
                db.markRead(sessionKey: sessionKey, seq: seq)
                // Update session in-memory immediately (no full reload delay)
                updateSessionInMemory(key: sessionKey, preview: preview, timestamp: timestamp, unread: 0)
            } else {
                let currentUnread = sessions.first(where: { $0.sessionKey == sessionKey })?.unreadCount ?? 0
                updateSessionInMemory(key: sessionKey, preview: preview, timestamp: timestamp, unread: currentUnread + 1)
                if var session = sessions.first(where: { $0.sessionKey == sessionKey }) {
                    session.unreadCount = currentUnread + 1
                    db.upsertSession(session)
                }

                // Type 1: cross-session notification
                let sessionTitle = sessions.first(where: { $0.sessionKey == sessionKey })?.title ?? Self.readableTitle(from: sessionKey)
                NotificationManager.shared.post(AppNotification(
                    type: .newMessage,
                    style: .pill,
                    title: sessionTitle,
                    subtitle: preview,
                    sessionKey: sessionKey
                ))
            }

            // Type 2: notify cards — fire regardless of active session
            postNotifyCards(from: text, sessionKey: sessionKey)

            logger.info("Persisted message to \(sessionKey, privacy: .public) seq=\(seq)")

        } else if state == "delta" {
            if sessionKey == currentSessionKey {
                if streamingMessage != nil {
                    // Update existing streaming message
                    if let idx = currentMessages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
                        currentMessages[idx].content = text
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

    // MARK: - Typing indicator

    /// Insert an empty streaming placeholder so the UI shows a typing indicator.
    func beginAgentResponse(sessionKey: String) {
        // If the session isn't open yet, open it first so messages land in the right place
        if currentSessionKey != sessionKey {
            logger.info("beginAgentResponse: auto-opening session \(sessionKey, privacy: .public)")
            openSession(key: sessionKey)
        }
        guard streamingMessage == nil else { return }
        let msg = Message(role: .agent, content: "", isStreaming: true)
        streamingMessage = msg
        currentMessages.append(msg)
    }

    /// Finalize the streaming message — stop typing indicator, mark as complete.
    func finalizeAgentResponse() {
        streamingMessage = nil
        if let idx = currentMessages.lastIndex(where: { $0.role == .agent && $0.isStreaming }) {
            currentMessages[idx].isStreaming = false
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
        let sendPreview = Self.generatePreview(from: text)
        db.updateSessionLastMessage(sessionKey: sessionKey, timestamp: now, preview: sendPreview, seq: cached.seq)

        // Add to UI immediately
        if sessionKey == currentSessionKey {
            currentMessages.append(cached.toMessage())
        }

        updateSessionInMemory(key: sessionKey, preview: sendPreview, timestamp: now, unread: 0)
        return (msgId, idempotencyKey)
    }

    // MARK: - In-memory session update

    /// Update session list in-memory for instant UI feedback (no SQLite roundtrip).
    private func updateSessionInMemory(key: String, preview: String, timestamp: Int64, unread: Int) {
        if let idx = sessions.firstIndex(where: { $0.sessionKey == key }) {
            sessions[idx].lastMessagePreview = preview
            sessions[idx].lastMessageAt = timestamp
            sessions[idx].unreadCount = unread
        }
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

    // MARK: - Delete

    func deleteSession(key: String) {
        db.deleteSession(key: key)
        sessions.removeAll { $0.sessionKey == key }
        if currentSessionKey == key {
            currentSessionKey = ""
            currentMessages = []
            streamingMessage = nil
        }
    }

    // MARK: - Cleanup

    func cleanupStale() {
        db.cleanupStaleSessions()
        loadSessions()
    }

    // MARK: - Notifications

    /// Parse notify cards from message text and post as in-app notifications.
    private func postNotifyCards(from text: String, sessionKey: String) {
        let result = CardParser.parse(text)
        for card in result.cards {
            switch card.type {
            case .notify:
                let kind = card.fields["kind"] ?? "system"
                let title = card.fields["title"] ?? "Notification"
                let subtitle = card.fields["subtitle"]
                let style: AppNotificationStyle = {
                    switch card.fields["style"]?.lowercased() {
                    case "card":   return .card
                    case "island": return .island
                    default:       return .pill
                    }
                }()
                NotificationManager.shared.post(AppNotification(
                    type: .from(notifyKind: kind),
                    style: style,
                    title: title,
                    subtitle: subtitle,
                    sessionKey: sessionKey
                ))

            case .notifyGit:
                let gitType = card.fields["type"] ?? "commit"
                let branch = card.fields["branch"] ?? ""
                let notifType: AppNotificationType = gitType == "deploy" ? .agentUpdate : .agentUpdate
                NotificationManager.shared.post(AppNotification(
                    type: notifType,
                    style: .island,
                    title: branch,
                    sessionKey: sessionKey,
                    visualCard: card
                ))

            case .notifyWorkflow:
                let workflow = card.fields["workflow"] ?? "workflow"
                let agents = card.fields["agents"] ?? ""
                NotificationManager.shared.post(AppNotification(
                    type: .agentUpdate,
                    style: .island,
                    title: "\(workflow) — \(agents) agents",
                    sessionKey: sessionKey,
                    visualCard: card
                ))

            case .notifySubagent:
                let status = card.fields["status"] ?? "running"
                let task = card.fields["task"] ?? ""
                let type: AppNotificationType = status == "done" ? .taskComplete : .agentUpdate
                NotificationManager.shared.post(AppNotification(
                    type: type,
                    style: .island,
                    title: task,
                    sessionKey: sessionKey,
                    visualCard: card
                ))

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    /// Generate a human-readable preview from message text.
    /// Strips code blocks and replaces card blocks with friendly labels.
    static func generatePreview(from text: String) -> String {
        let blocks = MessageParser.parse(text)

        var parts: [String] = []
        for block in blocks {
            switch block {
            case .text(_, let spans):
                let plainText = spans.map(\.text).joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !plainText.isEmpty {
                    parts.append(plainText)
                }
            case .code(_, let language, _):
                if !language.isEmpty {
                    parts.append("[\(language) code]")
                } else {
                    parts.append("[code]")
                }
            case .card(_, let card):
                let label = cardPreviewLabel(for: card)
                parts.append(label)
            case .divider:
                break
            }
        }

        let joined = parts.joined(separator: " ")
        if joined.isEmpty { return String(text.prefix(80)) }
        return String(joined.prefix(100))
    }

    private static func cardPreviewLabel(for card: ServiceCard) -> String {
        switch card.type {
        case .githubPR:
            let title = card.fields["title"] ?? ""
            return title.isEmpty ? "Pull Request" : "PR: \(title)"
        case .emailInbox, .emailDraft, .emailDigest:
            let subject = card.fields["subject"] ?? ""
            return subject.isEmpty ? "Email" : subject
        case .calendarEvent:
            let title = card.fields["title"] ?? ""
            return title.isEmpty ? "Calendar event" : title
        case .calendarConflict:
            return "Calendar conflict"
        case .todo:
            let title = card.fields["title"] ?? ""
            return title.isEmpty ? "Todo" : title
        default:
            return card.type.rawValue
        }
    }

    /// Extract a readable title from a session key like "agent:scout:abc123"
    static func readableTitle(from key: String) -> String {
        let parts = key.split(separator: ":")
        // "agent:scout:abc123" → "Scout"
        // "some-uuid" → "New Chat"
        if parts.count >= 2 {
            let name = String(parts[1])
            return name.prefix(1).uppercased() + name.dropFirst()
        }
        return "New Chat"
    }
}
