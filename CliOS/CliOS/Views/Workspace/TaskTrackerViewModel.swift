import SwiftUI
import Combine

@MainActor
class TaskTrackerViewModel: ObservableObject {
    @Published var boards: [BoardIndexEntry] = []
    @Published var selectedBoardId: String?
    @Published var boardFile: BoardFile?
    @Published var isLoading = false
    @Published var error: String?

    private var taskService: TaskService? {
        guard let gwURL = GatewayService.shared.gatewayURL,
              let host = gwURL.host,
              let token = GatewayService.shared.authToken else { return nil }
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        let base = URL(string: "\(scheme)://\(host):\(port)")!
        return TaskService(gatewayBaseURL: base, token: token)
    }

    var tasks: [TaskItem] { boardFile?.tasks ?? [] }
    var board: TaskBoard? { boardFile?.board }
    var currentFile: String? {
        boards.first(where: { $0.id == selectedBoardId })?.file
    }

    // MARK: - Load

    func loadIndex() async {
        guard let svc = taskService else {
            error = "Gateway not connected"
            return
        }
        do {
            let index = try await svc.fetchBoardIndex()
            boards = index.boards
            if selectedBoardId == nil, let first = boards.first {
                selectedBoardId = first.id
            }
            if let file = currentFile {
                await loadBoard(file: file)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadBoard(file: String) async {
        guard let svc = taskService else { return }
        isLoading = true
        do {
            boardFile = try await svc.fetchBoard(file: file)
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        if let file = currentFile {
            await loadBoard(file: file)
        } else {
            await loadIndex()
        }
    }

    // MARK: - Task operations

    func updateStatus(taskId: String, status: String) async {
        guard let svc = taskService, let file = currentFile else { return }
        do {
            try await svc.updateTaskStatus(file: file, taskId: taskId, status: status)
            await loadBoard(file: file)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(taskId: String) async {
        guard let svc = taskService, let file = currentFile else { return }
        do {
            try await svc.deleteTask(file: file, taskId: taskId)
            await loadBoard(file: file)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Returns true on success, false on failure (sets self.error).
    @discardableResult
    func updateTask(_ task: TaskItem) async -> Bool {
        guard let svc = taskService else {
            self.error = "Gateway not connected"
            return false
        }
        guard let file = currentFile else {
            self.error = "No board selected"
            return false
        }
        do {
            try await svc.updateTask(file: file, task: task)
            await loadBoard(file: file)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func addTask(_ task: TaskItem) async {
        guard let svc = taskService, let file = currentFile else { return }
        do {
            try await svc.addTask(file: file, task: task)
            await loadBoard(file: file)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createBoard(id: String, name: String) async {
        guard let svc = taskService else { return }
        do {
            try await svc.createBoard(id: id, name: name)
            await loadIndex()
            selectedBoardId = id
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectBoard(_ id: String) async {
        selectedBoardId = id
        if let file = currentFile {
            await loadBoard(file: file)
        }
    }

    // MARK: - Helpers

    func tasksForStatus(_ status: String) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }

    func nextStatus(for current: String) -> String? {
        switch current {
        case "backlog": return "todo"
        case "todo": return "in_progress"
        case "in_progress": return "done"
        default: return nil
        }
    }

    static func priorityColor(_ priority: String) -> Color? {
        switch priority {
        case "urgent": return Theme.error
        case "high": return Theme.accent
        case "medium": return Theme.warning
        case "low": return Color.gray
        default: return nil
        }
    }

    static func statusIcon(_ status: String) -> String {
        switch status {
        case "backlog": return "tray"
        case "todo": return "circle"
        case "in_progress": return "arrow.trianglehead.clockwise"
        case "done": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    static func isDueDateOverdue(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: dateString) {
            return date < Calendar.current.startOfDay(for: Date())
        }
        // Try plain yyyy-MM-dd
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let date = df.date(from: dateString) {
            return date < Calendar.current.startOfDay(for: Date())
        }
        return false
    }

    static func formatDueDate(_ dateString: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let date = df.date(from: dateString) {
            let out = DateFormatter()
            out.dateFormat = "MMM d"
            return out.string(from: date)
        }
        // Try ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: dateString) {
            let out = DateFormatter()
            out.dateFormat = "MMM d"
            return out.string(from: date)
        }
        return dateString
    }
}
