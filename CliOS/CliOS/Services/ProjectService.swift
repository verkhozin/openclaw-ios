import Foundation

/// Reads/writes project data via Gateway HTTP.
/// Files live in workspace/projects/ on VPS.
/// Follows the same pattern as TaskService.
class ProjectService {

    let baseURL: URL    // http://host:port/__openclaw__/canvas/projects/
    let token: String

    init(gatewayBaseURL: URL, token: String) {
        self.baseURL = gatewayBaseURL
            .appendingPathComponent("__openclaw__")
            .appendingPathComponent("canvas")
            .appendingPathComponent("projects")
        self.token = token
    }

    // MARK: - Read

    /// Fetch list of all projects
    func fetchProjectIndex() async throws -> ProjectIndex {
        let data = try await httpGet(path: "_index.json")
        return try JSONDecoder().decode(ProjectIndex.self, from: data)
    }

    /// Fetch a single project's metadata
    func fetchProject(id: String) async throws -> Project {
        let data = try await httpGet(path: "\(id)/project.json")
        return try JSONDecoder().decode(Project.self, from: data)
    }

    /// Fetch a project's task board
    func fetchProjectTasks(projectId: String, file: String) async throws -> BoardFile {
        let data = try await httpGet(path: "\(projectId)/tasks/\(file)")
        return try JSONDecoder().decode(BoardFile.self, from: data)
    }

    /// Fetch session→project mapping
    func fetchSessionMapping() async throws -> SessionMapping {
        let data = try await httpGet(path: "_sessions.json")
        return try JSONDecoder().decode(SessionMapping.self, from: data)
    }

    // MARK: - Write

    /// Save project metadata
    func saveProject(id: String, project: Project) async throws {
        try await httpPut(path: "\(id)/project.json", data: encode(project))
    }

    /// Save project index
    func saveProjectIndex(_ index: ProjectIndex) async throws {
        try await httpPut(path: "_index.json", data: encode(index))
    }

    /// Save a project's task board
    func saveProjectTasks(projectId: String, file: String, board: BoardFile) async throws {
        try await httpPut(path: "\(projectId)/tasks/\(file)", data: encode(board))
    }

    /// Save session→project mapping
    func saveSessionMapping(_ mapping: SessionMapping) async throws {
        try await httpPut(path: "_sessions.json", data: encode(mapping))
    }

    // MARK: - High-level Operations

    /// Create a new project with default task board
    func createProject(id: String, name: String, description: String) async throws -> Project {
        let now = ISO8601DateFormatter().string(from: Date())

        let project = Project(
            id: id,
            name: name,
            description: description,
            status: .active,
            createdAt: now,
            updatedAt: now
        )

        // Save project.json
        try await saveProject(id: id, project: project)

        // Create default task board
        let board = BoardFile(
            board: TaskBoard(
                id: "default",
                name: name,
                statuses: ["backlog", "todo", "in_progress", "done", "cancelled"],
                labels: [],
                updatedAt: now
            ),
            tasks: []
        )
        try await saveProjectTasks(projectId: id, file: "default.json", board: board)

        // Create task board index
        let taskIndex = BoardIndex(boards: [
            BoardIndexEntry(id: "default", name: name, file: "default.json", createdAt: now)
        ])
        try await httpPut(path: "\(id)/tasks/_index.json", data: encode(taskIndex))

        // Update project index
        var index = (try? await fetchProjectIndex()) ?? ProjectIndex(projects: [])
        index.projects.append(ProjectIndexEntry(
            id: id,
            name: name,
            status: ProjectStatus.active.rawValue,
            createdAt: now
        ))
        try await saveProjectIndex(index)

        return project
    }

    /// Archive a project (does NOT delete files)
    func archiveProject(id: String) async throws {
        var project = try await fetchProject(id: id)
        project.status = .archived
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        try await saveProject(id: id, project: project)

        // Update index entry status
        var index = try await fetchProjectIndex()
        if let idx = index.projects.firstIndex(where: { $0.id == id }) {
            index.projects[idx].status = ProjectStatus.archived.rawValue
        }
        try await saveProjectIndex(index)
    }

    // MARK: - HTTP

    private func httpGet(path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProjectServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
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
            throw ProjectServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    enum ProjectServiceError: Error {
        case httpError(Int)
    }
}
