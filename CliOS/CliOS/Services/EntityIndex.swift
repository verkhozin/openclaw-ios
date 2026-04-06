import Foundation
import SQLite3
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "EntityIndex")

/// Unified searchable index of all entities (files, tasks, sessions, agents, crons).
/// SQLite + FTS5 for fast full-text search. Singleton, thread-safe.
final class EntityIndex {
    static let shared = EntityIndex()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.clios.entityindex", qos: .userInitiated)

    /// Providers supply entities for each type.
    private var providers: [EntityType: EntityProvider] = [:]

    /// Reindex timer (lazy, fires every 2 minutes).
    private var reindexTimer: Timer?

    private init() {
        let url = Self.dbURL
        logger.info("Opening entity index at \(url.path, privacy: .public)")

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            logger.error("Failed to open entity index: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)")
            db = nil
            return
        }

        exec("PRAGMA journal_mode=WAL")
        createTables()
        logger.info("Entity index ready")
    }

    deinit {
        reindexTimer?.invalidate()
        sqlite3_close(db)
    }

    private static var dbURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("CLiOS", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("entities.sqlite3")
    }

    // MARK: - Schema

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS entities (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                name TEXT NOT NULL,
                path TEXT NOT NULL,
                subtitle TEXT NOT NULL DEFAULT '',
                icon TEXT NOT NULL DEFAULT '',
                updatedAt INTEGER NOT NULL DEFAULT 0,
                indexedAt INTEGER NOT NULL DEFAULT 0,
                usageCount INTEGER NOT NULL DEFAULT 0,
                lastUsedAt INTEGER NOT NULL DEFAULT 0
            )
        """)

        exec("CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(type)")
        exec("CREATE INDEX IF NOT EXISTS idx_entities_usage ON entities(usageCount DESC, lastUsedAt DESC)")

        // FTS5 virtual table for full-text search on name + subtitle
        exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entities_fts USING fts5(
                name,
                subtitle,
                content='entities',
                content_rowid='rowid',
                tokenize='unicode61 remove_diacritics 2'
            )
        """)

        // Triggers to keep FTS in sync with entities table
        exec("""
            CREATE TRIGGER IF NOT EXISTS entities_ai AFTER INSERT ON entities BEGIN
                INSERT INTO entities_fts(rowid, name, subtitle)
                VALUES (new.rowid, new.name, new.subtitle);
            END
        """)

        exec("""
            CREATE TRIGGER IF NOT EXISTS entities_ad AFTER DELETE ON entities BEGIN
                INSERT INTO entities_fts(entities_fts, rowid, name, subtitle)
                VALUES ('delete', old.rowid, old.name, old.subtitle);
            END
        """)

        exec("""
            CREATE TRIGGER IF NOT EXISTS entities_au AFTER UPDATE ON entities BEGIN
                INSERT INTO entities_fts(entities_fts, rowid, name, subtitle)
                VALUES ('delete', old.rowid, old.name, old.subtitle);
                INSERT INTO entities_fts(rowid, name, subtitle)
                VALUES (new.rowid, new.name, new.subtitle);
            END
        """)
    }

    // MARK: - Provider registration

    func register(provider: EntityProvider, for type: EntityType) {
        providers[type] = provider
        logger.info("Registered provider for \(type.rawValue, privacy: .public)")
    }

    // MARK: - Reindex

    /// Start periodic reindex timer (every 2 minutes).
    func startPeriodicReindex() {
        reindexTimer?.invalidate()
        reindexTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.reindexAll()
            }
        }
        logger.info("Periodic reindex started (every 120s)")
    }

    func stopPeriodicReindex() {
        reindexTimer?.invalidate()
        reindexTimer = nil
    }

    /// Reindex all registered providers.
    func reindexAll() async {
        logger.info("Reindexing all entity types...")
        for (type, provider) in providers {
            await reindex(type: type, provider: provider)
        }
        logger.info("Reindex complete")
    }

    /// Reindex a single entity type.
    func reindex(type: EntityType) async {
        guard let provider = providers[type] else {
            logger.warning("No provider registered for \(type.rawValue, privacy: .public)")
            return
        }
        await reindex(type: type, provider: provider)
    }

    private func reindex(type: EntityType, provider: EntityProvider) async {
        do {
            let entities = try await provider.fetchEntities()
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            queue.sync {
                // Get existing usage stats before clearing
                let usageMap = self.loadUsageStats(for: type)

                // Remove old entries for this type
                self.exec("DELETE FROM entities WHERE type = ?", params: [.text(type.rawValue)])

                // Insert fresh entries, preserving usage stats
                for var entity in entities {
                    if let stats = usageMap[entity.id] {
                        entity.usageCount = stats.count
                        entity.lastUsedAt = stats.lastUsedAt
                    }
                    entity.indexedAt = now
                    self.insertEntity(entity)
                }
            }

            logger.info("Reindexed \(entities.count) \(type.rawValue, privacy: .public) entities")
        } catch {
            logger.error("Reindex failed for \(type.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Ingest entities incrementally (e.g. from WebSocket events) without full reindex.
    func upsert(_ entities: [EntityItem]) {
        queue.sync {
            for entity in entities {
                // Preserve existing usage stats
                let existing = self.loadEntity(id: entity.id)
                var item = entity
                if let existing {
                    item.usageCount = existing.usageCount
                    item.lastUsedAt = existing.lastUsedAt
                }
                item.indexedAt = Int64(Date().timeIntervalSince1970 * 1000)
                self.insertEntity(item)
            }
        }
    }

    /// Remove entities by IDs.
    func remove(ids: [String]) {
        guard !ids.isEmpty else { return }
        queue.sync {
            for id in ids {
                self.exec("DELETE FROM entities WHERE id = ?", params: [.text(id)])
            }
        }
    }

    // MARK: - Search

    /// Search entities with optional type filter. Returns results ranked by relevance.
    func search(query: String, types: [EntityType]? = nil, limit: Int = 20) -> [EntityItem] {
        queue.sync {
            if query.isEmpty {
                return self.recentEntities(types: types, limit: limit)
            }

            // FTS5 query: prefix match for autocomplete
            let ftsQuery = query
                .split(separator: " ")
                .map { "\($0)*" }
                .joined(separator: " ")

            var sql: String
            var params: [SQLParam]

            if let types, !types.isEmpty {
                let placeholders = types.map { _ in "?" }.joined(separator: ", ")
                sql = """
                    SELECT e.id, e.type, e.name, e.path, e.subtitle, e.icon,
                           e.updatedAt, e.indexedAt, e.usageCount, e.lastUsedAt
                    FROM entities e
                    JOIN entities_fts f ON e.rowid = f.rowid
                    WHERE entities_fts MATCH ? AND e.type IN (\(placeholders))
                    ORDER BY e.usageCount DESC, e.lastUsedAt DESC
                    LIMIT ?
                """
                params = [.text(ftsQuery)] + types.map { .text($0.rawValue) } + [.int(Int64(limit))]
            } else {
                sql = """
                    SELECT e.id, e.type, e.name, e.path, e.subtitle, e.icon,
                           e.updatedAt, e.indexedAt, e.usageCount, e.lastUsedAt
                    FROM entities e
                    JOIN entities_fts f ON e.rowid = f.rowid
                    WHERE entities_fts MATCH ?
                    ORDER BY e.usageCount DESC, e.lastUsedAt DESC
                    LIMIT ?
                """
                params = [.text(ftsQuery), .int(Int64(limit))]
            }

            return self.queryEntities(sql: sql, params: params)
        }
    }

    /// Get recent/popular entities (for empty query state).
    private func recentEntities(types: [EntityType]?, limit: Int) -> [EntityItem] {
        var sql: String
        var params: [SQLParam]

        if let types, !types.isEmpty {
            let placeholders = types.map { _ in "?" }.joined(separator: ", ")
            sql = """
                SELECT id, type, name, path, subtitle, icon,
                       updatedAt, indexedAt, usageCount, lastUsedAt
                FROM entities
                WHERE type IN (\(placeholders))
                ORDER BY usageCount DESC, lastUsedAt DESC, updatedAt DESC
                LIMIT ?
            """
            params = types.map { .text($0.rawValue) } + [.int(Int64(limit))]
        } else {
            sql = """
                SELECT id, type, name, path, subtitle, icon,
                       updatedAt, indexedAt, usageCount, lastUsedAt
                FROM entities
                ORDER BY usageCount DESC, lastUsedAt DESC, updatedAt DESC
                LIMIT ?
            """
            params = [.int(Int64(limit))]
        }

        return queryEntities(sql: sql, params: params)
    }

    // MARK: - Usage tracking

    /// Record that user interacted with an entity (e.g. tapped it in @mention results).
    func recordUsage(id: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.sync {
            self.exec("""
                UPDATE entities SET usageCount = usageCount + 1, lastUsedAt = ? WHERE id = ?
            """, params: [.int(now), .text(id)])
        }
        logger.debug("Recorded usage for \(id, privacy: .public)")
    }

    // MARK: - Stats

    /// Total indexed entity count.
    func totalCount() -> Int {
        queue.sync {
            let sql = "SELECT COUNT(*) FROM entities"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    /// Count by type.
    func count(for type: EntityType) -> Int {
        queue.sync {
            let sql = "SELECT COUNT(*) FROM entities WHERE type = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    // MARK: - Internal helpers

    private func insertEntity(_ entity: EntityItem) {
        exec("""
            INSERT OR REPLACE INTO entities (id, type, name, path, subtitle, icon, updatedAt, indexedAt, usageCount, lastUsedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            .text(entity.id),
            .text(entity.type.rawValue),
            .text(entity.name),
            .text(entity.path),
            .text(entity.subtitle),
            .text(entity.icon),
            .int(entity.updatedAt),
            .int(entity.indexedAt),
            .int(Int64(entity.usageCount)),
            .int(entity.lastUsedAt)
        ])
    }

    private func loadEntity(id: String) -> EntityItem? {
        let sql = "SELECT id, type, name, path, subtitle, icon, updatedAt, indexedAt, usageCount, lastUsedAt FROM entities WHERE id = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return readEntity(stmt)
    }

    private func loadUsageStats(for type: EntityType) -> [String: (count: Int, lastUsedAt: Int64)] {
        let sql = "SELECT id, usageCount, lastUsedAt FROM entities WHERE type = ? AND usageCount > 0"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, nil)

        var map: [String: (count: Int, lastUsedAt: Int64)] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = col_text(stmt, 0)
            let count = Int(sqlite3_column_int(stmt, 1))
            let lastUsed = sqlite3_column_int64(stmt, 2)
            map[id] = (count, lastUsed)
        }
        return map
    }

    private func queryEntities(sql: String, params: [SQLParam]) -> [EntityItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("Query failed: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        bindParams(stmt, params)

        var results: [EntityItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readEntity(stmt))
        }
        return results
    }

    private func readEntity(_ stmt: OpaquePointer?) -> EntityItem {
        EntityItem(
            id: col_text(stmt, 0),
            type: EntityType(rawValue: col_text(stmt, 1)) ?? .file,
            name: col_text(stmt, 2),
            path: col_text(stmt, 3),
            subtitle: col_text(stmt, 4),
            icon: col_text(stmt, 5),
            updatedAt: sqlite3_column_int64(stmt, 6),
            indexedAt: sqlite3_column_int64(stmt, 7),
            usageCount: Int(sqlite3_column_int(stmt, 8)),
            lastUsedAt: sqlite3_column_int64(stmt, 9)
        )
    }

    // MARK: - SQL helpers

    private enum SQLParam {
        case text(String)
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

        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE && result != SQLITE_ROW {
            logger.error("SQL exec error: \(String(cString: sqlite3_errmsg(self.db!)), privacy: .public)")
        }
    }

    private func bindParams(_ stmt: OpaquePointer?, _ params: [SQLParam]) {
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case .text(let s):
                sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, nil)
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
}

// MARK: - Entity Provider Protocol

/// Provides entities of a given type for indexing.
/// Each source (files, tasks, sessions, etc.) implements this.
protocol EntityProvider {
    func fetchEntities() async throws -> [EntityItem]
}
