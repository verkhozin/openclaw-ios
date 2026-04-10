import Foundation
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "EntityProviders")

// MARK: - File Entity Provider

/// Indexes workspace files via FileService.
struct FileEntityProvider: EntityProvider {

    func fetchEntities() async throws -> [EntityItem] {
        let fileService = await FileService.shared
        var allItems: [EntityItem] = []

        // Recursively list up to 3 levels deep; full tree if small workspace
        try await listRecursive(
            path: "",
            depth: 0,
            maxDepth: 3,
            fileService: fileService,
            results: &allItems
        )

        logger.info("FileEntityProvider: indexed \(allItems.count) files")
        return allItems
    }

    private func listRecursive(
        path: String,
        depth: Int,
        maxDepth: Int,
        fileService: FileService,
        results: inout [EntityItem]
    ) async throws {
        let items: [FileItem]
        do {
            items = try await fileService.listDirectory(path: path)
        } catch {
            // If directory listing fails, skip silently
            logger.warning("Failed to list \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        for item in items {
            let entity = EntityItem(
                id: "file:\(item.path)",
                type: .file,
                name: item.name,
                path: item.path,
                subtitle: item.isDirectory ? "folder" : (item.formattedSize ?? ""),
                icon: item.iconName,
                updatedAt: 0 // FileItem doesn't track modification time yet
            )
            results.append(entity)

            // Recurse into directories if within depth limit
            if item.isDirectory && depth < maxDepth {
                // Stop if we already have a lot of entries (>5000)
                guard results.count < 5000 else {
                    logger.info("FileEntityProvider: hit 5000 limit at depth \(depth)")
                    return
                }
                try await listRecursive(
                    path: item.path,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    fileService: fileService,
                    results: &results
                )
            }
        }
    }
}

// MARK: - Task Entity Provider

/// Indexes tasks from all task boards via TaskService.
struct TaskEntityProvider: EntityProvider {

    func fetchEntities() async throws -> [EntityItem] {
        guard let gwURL = await GatewayService.shared.gatewayURL,
              let token = await GatewayService.shared.authToken else {
            return []
        }

        let host = gwURL.host ?? "localhost"
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        guard let baseURL = URL(string: "\(scheme)://\(host):\(port)") else { return [] }

        let service = TaskService(gatewayBaseURL: baseURL, token: token)

        var entities: [EntityItem] = []

        let index: BoardIndex
        do {
            index = try await service.fetchBoardIndex()
        } catch {
            logger.warning("TaskEntityProvider: failed to fetch board index: \(error.localizedDescription, privacy: .public)")
            return []
        }

        for entry in index.boards {
            do {
                let boardFile = try await service.fetchBoard(file: entry.file)
                for task in boardFile.tasks {
                    let statusEmoji: String
                    switch task.status {
                    case "done":        statusEmoji = "done"
                    case "in_progress": statusEmoji = "in progress"
                    case "todo":        statusEmoji = "todo"
                    case "cancelled":   statusEmoji = "cancelled"
                    default:            statusEmoji = task.status
                    }

                    entities.append(EntityItem(
                        id: "task:\(task.id)",
                        type: .task,
                        name: task.title,
                        path: "\(entry.name)/\(task.id)",
                        subtitle: "\(statusEmoji) · \(task.priority)",
                        icon: task.status == "done" ? "checkmark.circle.fill" : "circle",
                        updatedAt: Self.parseTimestamp(task.updatedAt)
                    ))
                }
            } catch {
                logger.warning("TaskEntityProvider: failed to fetch board \(entry.file, privacy: .public)")
            }
        }

        logger.info("TaskEntityProvider: indexed \(entities.count) tasks")
        return entities
    }

    private static func parseTimestamp(_ isoString: String) -> Int64 {
        let formatter = ISO8601DateFormatter()
        return Int64((formatter.date(from: isoString)?.timeIntervalSince1970 ?? 0) * 1000)
    }
}

// MARK: - Session Entity Provider

/// Indexes chat sessions from SessionStore/ChatDatabase.
struct SessionEntityProvider: EntityProvider {

    func fetchEntities() async throws -> [EntityItem] {
        let sessions = ChatDatabase.shared.allSessions()

        let entities = sessions.map { session in
            EntityItem(
                id: "session:\(session.sessionKey)",
                type: .session,
                name: session.title,
                path: session.sessionKey,
                subtitle: session.lastMessagePreview,
                icon: session.unreadCount > 0 ? "bubble.left.fill" : "bubble.left",
                updatedAt: session.lastMessageAt
            )
        }

        logger.info("SessionEntityProvider: indexed \(entities.count) sessions")
        return entities
    }
}

// MARK: - Agent Entity Provider

/// Indexes known agents from gateway status.
struct AgentEntityProvider: EntityProvider {

    func fetchEntities() async throws -> [EntityItem] {
        let status = await GatewayService.shared.status
        var entities: [EntityItem] = []

        // Always add the main agent if connected
        if status.isConnected {
            let name = status.agentName.isEmpty ? "main" : status.agentName
            entities.append(EntityItem(
                id: "agent:\(name)",
                type: .agent,
                name: name,
                path: name,
                subtitle: status.model,
                icon: "cpu"
            ))
        }

        // Add known agents from running tasks
        let tasks = await GatewayService.shared.tasks
        var seen = Set(entities.map(\.id))
        for task in tasks {
            let agentId = "agent:\(task.label)"
            guard !seen.contains(agentId) else { continue }
            seen.insert(agentId)
            entities.append(EntityItem(
                id: agentId,
                type: .agent,
                name: task.label,
                path: task.label,
                subtitle: task.status == .running ? "running" : task.status.rawValue,
                icon: task.status == .running ? "bolt.fill" : "cpu"
            ))
        }

        logger.info("AgentEntityProvider: indexed \(entities.count) agents")
        return entities
    }
}

// MARK: - Cron Entity Provider

/// Indexes cron jobs from GatewayService.
struct CronEntityProvider: EntityProvider {

    func fetchEntities() async throws -> [EntityItem] {
        let jobs = await GatewayService.shared.cronJobs

        let entities = jobs.map { job in
            EntityItem(
                id: "cron:\(job.id)",
                type: .cron,
                name: job.name,
                path: job.id,
                subtitle: job.enabled ? job.schedule : "disabled",
                icon: job.enabled ? "clock.fill" : "clock",
                updatedAt: Int64((job.lastRunAt?.timeIntervalSince1970 ?? 0) * 1000)
            )
        }

        logger.info("CronEntityProvider: indexed \(entities.count) cron jobs")
        return entities
    }
}

// MARK: - Calendar Event Entity Provider

/// Indexes calendar events from GatewayService.
struct CalendarEventEntityProvider: EntityProvider {

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    func fetchEntities() async throws -> [EntityItem] {
        let events = await GatewayService.shared.calendarEvents

        let entities = events.map { event in
            let subtitle: String
            if event.isAllDay {
                subtitle = "All day · \(event.source.rawValue)"
            } else {
                let start = Self.timeFormatter.string(from: event.startDate)
                let end = Self.timeFormatter.string(from: event.endDate)
                subtitle = "\(start) – \(end)"
            }

            return EntityItem(
                id: "event:\(event.id)",
                type: .event,
                name: event.title,
                path: event.id,
                subtitle: subtitle,
                icon: event.isAllDay ? "calendar.circle.fill" : "calendar",
                updatedAt: Int64(event.startDate.timeIntervalSince1970 * 1000)
            )
        }

        logger.info("CalendarEventEntityProvider: indexed \(entities.count) events")
        return entities
    }
}
