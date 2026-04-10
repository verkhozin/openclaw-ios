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

    /// Cached session→project mapping loaded from workspace/projects/_sessions.json
    private var sessionMapping = SessionMapping(sessions: [:])

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

        // Rebuild seenSeqs for this session from loaded messages to prevent dupes on reconnect
        seenSeqs[key] = Set(cached.compactMap { $0.seq > 0 ? $0.seq : nil })

        // Mark as read
        if let lastSeq = cached.last?.seq {
            db.markRead(sessionKey: key, seq: lastSeq)
        }

        loadSessions()
        logger.info("Opened session \(key, privacy: .public) with \(cached.count) cached messages (same=\(isSameSession))")

        // If cache is empty, fetch history from gateway
        if cached.isEmpty {
            Task {
                await GatewayService.shared.fetchHistory(sessionKey: key)
            }
        }
    }

    // MARK: - Receive messages from gateway

    /// Track seen seq numbers per session to prevent duplicates from reconnects
    private var seenSeqs: [String: Set<Int64>] = [:]

    /// Track notify cards already fired from streaming deltas — prevent double-fire on final
    private var firedNotifyCards: Set<String> = []

    /// Called when a chat delta/final event arrives.
    func handleChatEvent(sessionKey: String, state: String, text: String, seq: Int64, timestamp: Int64, runId: String?) {
        let isActive = sessionKey == currentSessionKey
        if state == "final" {
            logger.info("handleChatEvent FINAL: event=\(sessionKey, privacy: .public) current=\(self.currentSessionKey, privacy: .public) active=\(isActive) seq=\(seq) textLen=\(text.count)")
        }

        ensureSession(key: sessionKey)

        if state == "final" {
            // Dedup: skip if we already processed this seq for this session
            if seq > 0 && (seenSeqs[sessionKey]?.contains(seq) == true) {
                logger.info("Skipping duplicate final seq=\(seq) session=\(sessionKey)")
                return
            }
            if seq > 0 { seenSeqs[sessionKey, default: []].insert(seq) }

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

            // Extract session title from card if present
            let cardResult = CardParser.parse(text)
            if let titleCard = cardResult.cards.first(where: { $0.type == .sessionTitle }),
               let title = titleCard.fields["title"], !title.isEmpty {
                updateTitle(sessionKey: sessionKey, title: title)
            }

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

            // Fire notify cards from deltas immediately (don't wait for final)
            postNotifyCards(from: text, sessionKey: sessionKey)
        }
    }

    // MARK: - Session title

    func updateTitle(sessionKey: String, title: String) {
        db.updateSessionTitle(sessionKey: sessionKey, title: title)
        if let idx = sessions.firstIndex(where: { $0.sessionKey == sessionKey }) {
            sessions[idx].title = title
        }
        logger.info("Session title updated: \(sessionKey, privacy: .public) → \(title)")
    }

    // MARK: - Typing indicator

    /// Insert an empty streaming placeholder so the UI shows a typing indicator.
    /// Only call this for the currently active session.
    func beginAgentResponse(sessionKey: String) {
        firedNotifyCards.removeAll()
        guard sessionKey == currentSessionKey else { return }
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

        // Set session title from first user message (fallback until agent names it)
        if let session = sessions.first(where: { $0.sessionKey == sessionKey }),
           session.title == "New Chat" {
            let truncated = String(text.prefix(40)) + (text.count > 40 ? "..." : "")
            updateTitle(sessionKey: sessionKey, title: truncated)
        }

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

    // MARK: - Demo mode

    func clearSessionsForDemo() {
        sessions = []
        currentSessionKey = ""
        currentMessages = []
        streamingMessage = nil
        seenSeqs = [:]
        firedNotifyCards = []
        logger.info("Sessions cleared from UI for demo (DB untouched)")
    }

    // MARK: - Cleanup

    func cleanupStale() {
        db.cleanupStaleSessions()
        loadSessions()
    }

    // MARK: - Notifications

    /// Parse notify cards from message text and post as in-app notification banners.
    /// Cards themselves are not rendered in the chat — only the banner is shown.
    /// Deduplicates by card type + key fields so streaming deltas don't re-fire.
    private func postNotifyCards(from text: String, sessionKey: String) {
        let result = CardParser.parse(text)
        for card in result.cards {
            // Dedup key: type + distinguishing fields
            let dedupKey: String
            switch card.type {
            case .notify:           dedupKey = "notify:\(card.fields["title"] ?? "")"
            case .notifyGit:        dedupKey = "git:\(card.fields["branch"] ?? "")"
            case .notifyWorkflow:   dedupKey = "workflow:\(card.fields["workflow"] ?? "")"
            case .notifySubagent:   dedupKey = "subagent:\(card.fields["task"] ?? "")"
            default:                dedupKey = ""
            }
            if !dedupKey.isEmpty {
                guard !firedNotifyCards.contains(dedupKey) else { continue }
                firedNotifyCards.insert(dedupKey)
            }

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

    // MARK: - Gateway history sync

    /// Ingest message history returned by `chat.history` into SQLite and refresh UI.
    ///
    /// Strategy:
    /// 1. Clear old history-fetched messages (seq=0) — these are stale snapshots
    /// 2. Build content fingerprint set from remaining real-time messages to avoid dupes
    /// 3. Insert new history messages with seq=0 (won't interfere with real-time seq dedup)
    func ingestHistory(sessionKey: String, rawMessages: [[String: Any]]) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Step 1: clear previous history-fetched messages, keep real-time ones
        db.deleteHistoryMessages(sessionKey: sessionKey)

        // Step 2: content dedup — skip messages that already exist from real-time events
        let existingContent = db.existingContentSet(for: sessionKey)

        var ingestedCount = 0

        for (index, msg) in rawMessages.enumerated() {
            let role = msg["role"] as? String ?? "assistant"

            // Extract text: either a plain string or content array
            let text: String
            if let s = msg["content"] as? String {
                text = s
            } else if let arr = msg["content"] as? [[String: Any]] {
                text = arr.compactMap { $0["text"] as? String }.joined()
            } else {
                continue
            }
            guard !text.isEmpty else { continue }

            // Skip if identical content already stored from a real-time event
            if existingContent.contains(text) { continue }

            let parsed = ContentParser.parse(text)
            let msgId = (msg["id"] as? String) ?? "\(sessionKey)-hist-\(index)"
            let rawTs = (msg["timestamp"] as? Int64) ?? Int64(msg["timestamp"] as? Double ?? 0)
            let timestamp = rawTs > 0 ? rawTs : (now - Int64((rawMessages.count - index) * 1000))

            let cached = CachedMessage(
                id: msgId,
                sessionKey: sessionKey,
                role: role,
                rawContent: text,
                parsedBlocksJSON: parsed.parsedBlocksJSON,
                tagsJSON: parsed.tagsJSON,
                hasCode: parsed.hasCode,
                hasCard: parsed.hasCard,
                cardType: parsed.cardType,
                timestamp: timestamp,
                seq: 0,         // seq=0 = history-fetched, won't clash with real-time seq dedup
                runId: nil
            )
            db.insertMessage(cached)
            ingestedCount += 1
        }

        // Update session metadata
        if let lastMsg = rawMessages.last {
            let lastText: String
            if let s = lastMsg["content"] as? String { lastText = s }
            else if let arr = lastMsg["content"] as? [[String: Any]] {
                lastText = arr.compactMap { $0["text"] as? String }.joined()
            } else { lastText = "" }
            let preview = Self.generatePreview(from: lastText)
            let ts = (lastMsg["timestamp"] as? Int64) ?? now
            db.updateSessionLastMessage(sessionKey: sessionKey, timestamp: ts, preview: preview, seq: 0)
        }

        // Refresh UI if viewing this session
        if sessionKey == currentSessionKey {
            let cached = db.messages(for: sessionKey, limit: 50)
            currentMessages = cached.map { $0.toMessage() }
            seenSeqs[sessionKey] = Set(cached.compactMap { $0.seq > 0 ? $0.seq : nil })
        }

        loadSessions()
        logger.info("Ingested \(ingestedCount) history messages for \(sessionKey, privacy: .public)")
    }

    /// Merge server session list into local SQLite cache.
    func mergeSessions(from serverSessions: [[String: Any]]) {
        for entry in serverSessions {
            guard let rawKey = entry["key"] as? String else { continue }
            if rawKey == "global" || rawKey == "unknown" { continue }

            // Resolve gateway key (agent:scout:uuid) to local key if it exists
            let key = resolveSessionKey(rawKey)

            let serverTitle = (entry["derivedTitle"] as? String)
                ?? (entry["displayName"] as? String)
            let updatedAt = (entry["updatedAt"] as? Int64)
                ?? Int64(entry["updatedAt"] as? Double ?? 0)
            let rawPreview = (entry["lastMessagePreview"] as? String) ?? ""
            let preview = rawPreview.isEmpty ? "" : Self.generatePreview(from: rawPreview)
            let model = (entry["model"] as? String) ?? ""

            let existing = db.session(for: key)

            // Title priority: existing non-default local title > clean server title > readableTitle
            // Local title wins because it's set by session.title card or first user message,
            // while server derivedTitle may be garbage from system-event prompt.
            let defaultTitles: Set<String> = ["New Chat", "Main"]
            let title: String = {
                if let et = existing?.title, !et.isEmpty, !defaultTitles.contains(et) { return et }
                if let st = serverTitle, !st.isEmpty, !st.contains("```"), !st.contains("sender(") { return st }
                return Self.readableTitle(from: key)
            }()

            // Only update if server is newer or session doesn't exist locally
            if existing == nil || (existing!.lastMessageAt < updatedAt && updatedAt > 0) {
                let session = ChatSession(
                    sessionKey: key,
                    title: title,
                    lastMessageAt: updatedAt > 0 ? updatedAt : (existing?.lastMessageAt ?? 0),
                    lastMessagePreview: preview.isEmpty ? (existing?.lastMessagePreview ?? "") : preview,
                    unreadCount: existing?.unreadCount ?? 0,
                    agentId: existing?.agentId ?? "",
                    model: model.isEmpty ? (existing?.model ?? "") : model,
                    cachedUntilSeq: existing?.cachedUntilSeq ?? 0
                )
                db.upsertSession(session)
            }
        }
        loadSessions()
        logger.info("Merged \(serverSessions.count) sessions from gateway")
    }

    // MARK: - Session key resolution

    /// Resolve a gateway session key to a local session key.
    ///
    /// The gateway wraps session keys as `agent:<name>:<uuid>`, e.g.
    /// `agent:scout:88e7a5f6-11f2-4e08-a4e6-f488b6f92386`.
    /// The app creates sessions with plain UUID keys like `88E7A5F6-...`.
    /// This method maps the gateway key back to the local key so events
    /// route to the correct session.
    func resolveSessionKey(_ key: String) -> String {
        // Exact match — already known
        if key == currentSessionKey { return key }
        if sessions.contains(where: { $0.sessionKey == key }) { return key }

        // Extract UUID suffix from agent:*:uuid
        let parts = key.split(separator: ":", maxSplits: 2)
        guard parts.count == 3, parts[0] == "agent" else { return key }
        let uuidPart = String(parts[2])

        // Match against current session (case-insensitive)
        if !currentSessionKey.isEmpty &&
            currentSessionKey.caseInsensitiveCompare(uuidPart) == .orderedSame {
            return currentSessionKey
        }

        // Match against any known session
        if let match = sessions.first(where: {
            $0.sessionKey.caseInsensitiveCompare(uuidPart) == .orderedSame
        }) {
            return match.sessionKey
        }

        return key
    }

    // MARK: - Project mapping

    /// Load session→project mapping from workspace via ProjectService.
    func loadSessionMapping() async {
        guard let service = makeProjectService() else { return }
        do {
            sessionMapping = try await service.fetchSessionMapping()
            logger.info("Loaded session mapping: \(self.sessionMapping.sessions.count) entries")
        } catch {
            // File may not exist yet — start with empty mapping
            sessionMapping = SessionMapping(sessions: [:])
            logger.info("No session mapping found, starting empty")
        }
    }

    /// Get the project ID for a session, if any.
    func projectId(for sessionKey: String) -> String? {
        sessionMapping.sessions[sessionKey]
    }

    /// Link a session to a project and persist the mapping.
    func linkSession(_ sessionKey: String, to projectId: String) {
        sessionMapping.sessions[sessionKey] = projectId
        persistSessionMapping()
    }

    /// Unlink a session from its project and persist the mapping.
    func unlinkSession(_ sessionKey: String) {
        sessionMapping.sessions.removeValue(forKey: sessionKey)
        persistSessionMapping()
    }

    /// Return sessions that belong to a given project.
    func sessions(for projectId: String) -> [ChatSession] {
        let linkedKeys = sessionMapping.sessions
            .filter { $0.value == projectId }
            .map(\.key)
        let keySet = Set(linkedKeys)
        return sessions.filter { keySet.contains($0.sessionKey) }
    }

    private func persistSessionMapping() {
        guard let service = makeProjectService() else { return }
        let mapping = sessionMapping
        Task {
            do {
                try await service.saveSessionMapping(mapping)
                logger.info("Session mapping saved")
            } catch {
                logger.warning("Failed to save session mapping: \(error.localizedDescription)")
            }
        }
    }

    private func makeProjectService() -> ProjectService? {
        guard let gwURL = GatewayService.shared.gatewayURL,
              let token = GatewayService.shared.authToken else { return nil }
        let host = gwURL.host ?? "localhost"
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        guard let baseURL = URL(string: "\(scheme)://\(host):\(port)") else { return nil }
        return ProjectService(gatewayBaseURL: baseURL, token: token)
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
                let raw = spans.map(\.text).joined()
                let collapsed = raw.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !collapsed.isEmpty {
                    parts.append(collapsed)
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
        if joined.isEmpty {
            // Parser may fail on single-line or truncated code fences — detect them manually
            if text.contains("```") {
                let afterFence = text.components(separatedBy: "```").dropFirst().first ?? ""
                let lang = afterFence.components(separatedBy: .whitespacesAndNewlines).first ?? ""
                if lang.hasPrefix("card:") {
                    // card:notify.git → "Notification", card:github.pr → "Pull Request"
                    let cardType = ServiceCard.CardType(rawValue: String(lang.dropFirst(5)))
                    return cardPreviewLabel(for: ServiceCard(type: cardType ?? .unknown, fields: [:]))
                }
                return lang.isEmpty ? "[code]" : "[\(lang) code]"
            }
            return String(text.prefix(80))
        }
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
        case .notify, .notifyGit, .notifyWorkflow, .notifySubagent:
            return "Notification"
        case .sessionTitle:
            return card.fields["title"] ?? ""
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
