import Foundation
import SQLite3
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "ChatDatabase")

/// SQLite persistence for chat messages, sessions, and client metadata.
/// All public methods are thread-safe (serialized on a dispatch queue).
final class ChatDatabase {
    static let shared = ChatDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.clios.chatdb", qos: .userInitiated)

    private init() {
        let url = Self.dbURL
        logger.info("Opening database at \(url.path, privacy: .public)")

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            logger.error("Failed to open database: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)")
            db = nil
            return
        }

        // WAL mode for better concurrency
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA foreign_keys=ON")
        createTables()
        logger.info("Database ready")
    }

    deinit {
        sqlite3_close(db)
    }

    private static var dbURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("CLiOS", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("chat.sqlite3")
    }

    // MARK: - Schema

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS sessions (
                sessionKey TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                lastMessageAt INTEGER NOT NULL DEFAULT 0,
                lastMessagePreview TEXT NOT NULL DEFAULT '',
                unreadCount INTEGER NOT NULL DEFAULT 0,
                agentId TEXT NOT NULL DEFAULT '',
                model TEXT NOT NULL DEFAULT '',
                cachedUntilSeq INTEGER NOT NULL DEFAULT 0
            )
        """)

        exec("""
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                sessionKey TEXT NOT NULL,
                role TEXT NOT NULL,
                rawContent TEXT NOT NULL,
                parsedBlocksJSON TEXT,
                tagsJSON TEXT,
                hasCode INTEGER NOT NULL DEFAULT 0,
                hasCard INTEGER NOT NULL DEFAULT 0,
                cardType TEXT,
                timestamp INTEGER NOT NULL,
                seq INTEGER NOT NULL DEFAULT 0,
                runId TEXT,
                FOREIGN KEY (sessionKey) REFERENCES sessions(sessionKey) ON DELETE CASCADE
            )
        """)

        exec("CREATE INDEX IF NOT EXISTS idx_messages_session_seq ON messages(sessionKey, seq)")
        exec("CREATE INDEX IF NOT EXISTS idx_messages_session_ts ON messages(sessionKey, timestamp)")
        exec("CREATE INDEX IF NOT EXISTS idx_messages_hasCode ON messages(hasCode) WHERE hasCode = 1")
        exec("CREATE INDEX IF NOT EXISTS idx_messages_hasCard ON messages(hasCard) WHERE hasCard = 1")

        exec("""
            CREATE TABLE IF NOT EXISTS session_metadata (
                sessionKey TEXT PRIMARY KEY,
                lastReadSeq INTEGER NOT NULL DEFAULT 0,
                pinned INTEGER NOT NULL DEFAULT 0,
                muted INTEGER NOT NULL DEFAULT 0,
                customTitle TEXT,
                folder TEXT
            )
        """)

        exec("""
            CREATE TABLE IF NOT EXISTS client_metadata (
                messageId TEXT PRIMARY KEY,
                tagsJSON TEXT,
                pinned INTEGER NOT NULL DEFAULT 0,
                note TEXT,
                bookmarked INTEGER NOT NULL DEFAULT 0,
                reaction TEXT,
                FOREIGN KEY (messageId) REFERENCES messages(id) ON DELETE CASCADE
            )
        """)

        // Pending outbox for offline sends
        exec("""
            CREATE TABLE IF NOT EXISTS outbox (
                id TEXT PRIMARY KEY,
                sessionKey TEXT NOT NULL,
                content TEXT NOT NULL,
                idempotencyKey TEXT NOT NULL,
                createdAt INTEGER NOT NULL
            )
        """)
    }

    // MARK: - Sessions

    func upsertSession(_ session: ChatSession) {
        queue.sync {
            exec("""
                INSERT INTO sessions (sessionKey, title, lastMessageAt, lastMessagePreview, unreadCount, agentId, model, cachedUntilSeq)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(sessionKey) DO UPDATE SET
                    title = excluded.title,
                    lastMessageAt = excluded.lastMessageAt,
                    lastMessagePreview = excluded.lastMessagePreview,
                    unreadCount = excluded.unreadCount,
                    agentId = excluded.agentId,
                    model = excluded.model,
                    cachedUntilSeq = excluded.cachedUntilSeq
            """, params: [
                .text(session.sessionKey),
                .text(session.title),
                .int(session.lastMessageAt),
                .text(session.lastMessagePreview),
                .int(Int64(session.unreadCount)),
                .text(session.agentId),
                .text(session.model),
                .int(session.cachedUntilSeq)
            ])
        }
    }

    func allSessions() -> [ChatSession] {
        queue.sync {
            var results: [ChatSession] = []
            let sql = "SELECT sessionKey, title, lastMessageAt, lastMessagePreview, unreadCount, agentId, model, cachedUntilSeq FROM sessions ORDER BY lastMessageAt DESC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ChatSession(
                    sessionKey: col_text(stmt, 0),
                    title: col_text(stmt, 1),
                    lastMessageAt: sqlite3_column_int64(stmt, 2),
                    lastMessagePreview: col_text(stmt, 3),
                    unreadCount: Int(sqlite3_column_int(stmt, 4)),
                    agentId: col_text(stmt, 5),
                    model: col_text(stmt, 6),
                    cachedUntilSeq: sqlite3_column_int64(stmt, 7)
                ))
            }
            return results
        }
    }

    func session(for key: String) -> ChatSession? {
        queue.sync {
            let sql = "SELECT sessionKey, title, lastMessageAt, lastMessagePreview, unreadCount, agentId, model, cachedUntilSeq FROM sessions WHERE sessionKey = ? LIMIT 1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return ChatSession(
                sessionKey: col_text(stmt, 0),
                title: col_text(stmt, 1),
                lastMessageAt: sqlite3_column_int64(stmt, 2),
                lastMessagePreview: col_text(stmt, 3),
                unreadCount: Int(sqlite3_column_int(stmt, 4)),
                agentId: col_text(stmt, 5),
                model: col_text(stmt, 6),
                cachedUntilSeq: sqlite3_column_int64(stmt, 7)
            )
        }
    }

    func updateSessionLastMessage(sessionKey: String, timestamp: Int64, preview: String, seq: Int64) {
        queue.sync {
            exec("""
                UPDATE sessions SET lastMessageAt = ?, lastMessagePreview = ?, cachedUntilSeq = MAX(cachedUntilSeq, ?)
                WHERE sessionKey = ?
            """, params: [.int(timestamp), .text(preview), .int(seq), .text(sessionKey)])
        }
    }

    // MARK: - Messages

    func insertMessage(_ msg: CachedMessage) {
        queue.sync {
            exec("""
                INSERT OR REPLACE INTO messages (id, sessionKey, role, rawContent, parsedBlocksJSON, tagsJSON, hasCode, hasCard, cardType, timestamp, seq, runId)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, params: [
                .text(msg.id),
                .text(msg.sessionKey),
                .text(msg.role),
                .text(msg.rawContent),
                .textOrNull(msg.parsedBlocksJSON),
                .textOrNull(msg.tagsJSON),
                .int(msg.hasCode ? 1 : 0),
                .int(msg.hasCard ? 1 : 0),
                .textOrNull(msg.cardType),
                .int(msg.timestamp),
                .int(msg.seq),
                .textOrNull(msg.runId)
            ])
        }
    }

    func messages(for sessionKey: String, limit: Int = 50, beforeSeq: Int64? = nil) -> [CachedMessage] {
        queue.sync {
            var sql: String
            var params: [SQLParam] = [.text(sessionKey)]

            if let before = beforeSeq {
                sql = "SELECT * FROM messages WHERE sessionKey = ? AND seq < ? ORDER BY timestamp DESC, seq DESC LIMIT ?"
                params.append(.int(before))
            } else {
                sql = "SELECT * FROM messages WHERE sessionKey = ? ORDER BY timestamp DESC, seq DESC LIMIT ?"
            }
            params.append(.int(Int64(limit)))

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            bindParams(stmt, params)

            var results: [CachedMessage] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(CachedMessage(
                    id: col_text(stmt, 0),
                    sessionKey: col_text(stmt, 1),
                    role: col_text(stmt, 2),
                    rawContent: col_text(stmt, 3),
                    parsedBlocksJSON: col_text_opt(stmt, 4),
                    tagsJSON: col_text_opt(stmt, 5),
                    hasCode: sqlite3_column_int(stmt, 6) != 0,
                    hasCard: sqlite3_column_int(stmt, 7) != 0,
                    cardType: col_text_opt(stmt, 8),
                    timestamp: sqlite3_column_int64(stmt, 9),
                    seq: sqlite3_column_int64(stmt, 10),
                    runId: col_text_opt(stmt, 11)
                ))
            }
            return results.reversed() // oldest first
        }
    }

    func lastSeq(for sessionKey: String) -> Int64 {
        queue.sync {
            let sql = "SELECT MAX(seq) FROM messages WHERE sessionKey = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (sessionKey as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return sqlite3_column_int64(stmt, 0)
        }
    }

    // MARK: - Session metadata

    func lastReadSeq(for sessionKey: String) -> Int64 {
        queue.sync {
            let sql = "SELECT lastReadSeq FROM session_metadata WHERE sessionKey = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (sessionKey as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return sqlite3_column_int64(stmt, 0)
        }
    }

    func markRead(sessionKey: String, seq: Int64) {
        queue.sync {
            exec("""
                INSERT INTO session_metadata (sessionKey, lastReadSeq)
                VALUES (?, ?)
                ON CONFLICT(sessionKey) DO UPDATE SET lastReadSeq = MAX(lastReadSeq, excluded.lastReadSeq)
            """, params: [.text(sessionKey), .int(seq)])

            exec("UPDATE sessions SET unreadCount = 0 WHERE sessionKey = ?", params: [.text(sessionKey)])
        }
    }

    // MARK: - Outbox (offline queue)

    func enqueueOutbox(id: String, sessionKey: String, content: String, idempotencyKey: String) {
        queue.sync {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            exec("""
                INSERT OR REPLACE INTO outbox (id, sessionKey, content, idempotencyKey, createdAt)
                VALUES (?, ?, ?, ?, ?)
            """, params: [.text(id), .text(sessionKey), .text(content), .text(idempotencyKey), .int(now)])
        }
    }

    func pendingOutbox() -> [(id: String, sessionKey: String, content: String, idempotencyKey: String)] {
        queue.sync {
            let sql = "SELECT id, sessionKey, content, idempotencyKey FROM outbox ORDER BY createdAt ASC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            var results: [(String, String, String, String)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((col_text(stmt, 0), col_text(stmt, 1), col_text(stmt, 2), col_text(stmt, 3)))
            }
            return results
        }
    }

    func removeFromOutbox(id: String) {
        queue.sync {
            exec("DELETE FROM outbox WHERE id = ?", params: [.text(id)])
        }
    }

    // MARK: - Delete session

    func deleteSession(key: String) {
        queue.sync {
            exec("DELETE FROM messages WHERE sessionKey = ?", params: [.text(key)])
            exec("DELETE FROM outbox WHERE sessionKey = ?", params: [.text(key)])
            exec("DELETE FROM sessions WHERE sessionKey = ?", params: [.text(key)])
            logger.info("Deleted session \(key, privacy: .public)")
        }
    }

    // MARK: - Cleanup

    func cleanupStaleSessions(olderThanDays: Int = 30) {
        queue.sync {
            let cutoff = Int64(Date().timeIntervalSince1970 * 1000) - Int64(olderThanDays) * 86400 * 1000
            // Delete messages for stale sessions (but keep client_metadata)
            exec("""
                DELETE FROM messages WHERE sessionKey IN (
                    SELECT sessionKey FROM sessions WHERE lastMessageAt < ? AND sessionKey NOT IN (
                        SELECT sessionKey FROM session_metadata WHERE pinned = 1
                    )
                )
            """, params: [.int(cutoff)])

            exec("""
                DELETE FROM sessions WHERE lastMessageAt < ? AND sessionKey NOT IN (
                    SELECT sessionKey FROM session_metadata WHERE pinned = 1
                )
            """, params: [.int(cutoff)])

            logger.info("Cleaned up sessions older than \(olderThanDays) days")
        }
    }

    // MARK: - SQL helpers

    private enum SQLParam {
        case text(String)
        case textOrNull(String?)
        case int(Int64)
    }

    private func exec(_ sql: String, params: [SQLParam] = []) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("SQL prepare error: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)\nSQL: \(sql, privacy: .public)")
            return
        }
        defer { sqlite3_finalize(stmt) }
        bindParams(stmt, params)

        if sqlite3_step(stmt) != SQLITE_DONE && sqlite3_step(stmt) != SQLITE_ROW {
            logger.error("SQL exec error: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)")
        }
    }

    private func bindParams(_ stmt: OpaquePointer?, _ params: [SQLParam]) {
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case .text(let s):
                sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, nil)
            case .textOrNull(let s):
                if let s {
                    sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, idx)
                }
            case .int(let v):
                sqlite3_bind_int64(stmt, idx, v)
            }
        }
    }

    private func col_text(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        if let p = sqlite3_column_text(stmt, col) {
            return String(cString: p)
        }
        return ""
    }

    private func col_text_opt(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        if sqlite3_column_type(stmt, col) == SQLITE_NULL { return nil }
        if let p = sqlite3_column_text(stmt, col) {
            return String(cString: p)
        }
        return nil
    }
}
