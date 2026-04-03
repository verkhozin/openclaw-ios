import Foundation

// MARK: - Models

struct TaskBoard: Codable, Identifiable {
    let id: String
    var name: String
    var statuses: [String]
    var labels: [String]
    var updatedAt: String
}

struct TaskItem: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var status: String          // backlog, todo, in_progress, done, cancelled
    var priority: String        // urgent, high, medium, low, none
    var labels: [String]
    var assignee: String?       // "human", "agent", or name
    var agentCanDo: Bool        // can agent complete this without human help?
    var dueDate: String?        // ISO date "2026-04-07"
    var createdAt: String
    var updatedAt: String
}

struct BoardFile: Codable {
    var board: TaskBoard
    var tasks: [TaskItem]
}

struct BoardIndex: Codable {
    var boards: [BoardIndexEntry]
}

struct BoardIndexEntry: Codable, Identifiable {
    let id: String
    var name: String
    var file: String
    var createdAt: String
}

// MARK: - Task Service

/// Reads/writes task boards via Gateway HTTP.
/// Files live in workspace/tasks/ on VPS.
/// Both app and agent read/write the same JSON files.
class TaskService {
    
    let baseURL: URL    // http://host:port/__openclaw__/canvas/tasks/
    let token: String
    
    init(gatewayBaseURL: URL, token: String) {
        self.baseURL = gatewayBaseURL
            .appendingPathComponent("__openclaw__")
            .appendingPathComponent("canvas")
            .appendingPathComponent("tasks")
        self.token = token
    }
    
    // MARK: - Read
    
    /// Fetch list of all boards
    func fetchBoardIndex() async throws -> BoardIndex {
        let data = try await httpGet(path: "_index.json")
        return try JSONDecoder().decode(BoardIndex.self, from: data)
    }
    
    /// Fetch a specific board with all tasks
    func fetchBoard(file: String) async throws -> BoardFile {
        let data = try await httpGet(path: file)
        return try JSONDecoder().decode(BoardFile.self, from: data)
    }
    
    // MARK: - Write
    
    /// Save board file back to VPS
    func saveBoard(file: String, board: BoardFile) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(board)
        try await httpPut(path: file, data: data)
    }
    
    /// Save board index
    func saveBoardIndex(_ index: BoardIndex) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try await httpPut(path: "_index.json", data: data)
    }
    
    // MARK: - Task Operations
    
    /// Add task to a board
    func addTask(file: String, task: TaskItem) async throws {
        var board = try await fetchBoard(file: file)
        board.tasks.append(task)
        board.board.updatedAt = ISO8601DateFormatter().string(from: Date())
        try await saveBoard(file: file, board: board)
    }
    
    /// Update task status
    func updateTaskStatus(file: String, taskId: String, status: String) async throws {
        var board = try await fetchBoard(file: file)
        if let idx = board.tasks.firstIndex(where: { $0.id == taskId }) {
            board.tasks[idx].status = status
            board.tasks[idx].updatedAt = ISO8601DateFormatter().string(from: Date())
            board.board.updatedAt = board.tasks[idx].updatedAt
        }
        try await saveBoard(file: file, board: board)
    }
    
    /// Update full task
    func updateTask(file: String, task: TaskItem) async throws {
        var board = try await fetchBoard(file: file)
        if let idx = board.tasks.firstIndex(where: { $0.id == task.id }) {
            board.tasks[idx] = task
            board.board.updatedAt = ISO8601DateFormatter().string(from: Date())
        }
        try await saveBoard(file: file, board: board)
    }
    
    /// Delete task
    func deleteTask(file: String, taskId: String) async throws {
        var board = try await fetchBoard(file: file)
        board.tasks.removeAll { $0.id == taskId }
        board.board.updatedAt = ISO8601DateFormatter().string(from: Date())
        try await saveBoard(file: file, board: board)
    }
    
    /// Create new board
    func createBoard(id: String, name: String) async throws {
        let file = "\(id).json"
        let board = BoardFile(
            board: TaskBoard(
                id: id,
                name: name,
                statuses: ["backlog", "todo", "in_progress", "done", "cancelled"],
                labels: [],
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            tasks: []
        )
        try await saveBoard(file: file, board: board)
        
        // Update index
        var index = (try? await fetchBoardIndex()) ?? BoardIndex(boards: [])
        index.boards.append(BoardIndexEntry(
            id: id,
            name: name,
            file: file,
            createdAt: ISO8601DateFormatter().string(from: Date())
        ))
        try await saveBoardIndex(index)
    }
    
    // MARK: - HTTP
    
    private func httpGet(path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TaskServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
    
    private func httpPut(path: String, data: Data) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TaskServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    enum TaskServiceError: Error {
        case httpError(Int)
    }
}
