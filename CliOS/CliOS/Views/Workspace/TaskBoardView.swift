import SwiftUI

struct TaskBoardView: View {
    @ObservedObject var vm: TaskTrackerViewModel
    @State private var selectedTask: TaskItem?
    @State private var moveTask: TaskItem?

    private let columns = ["backlog", "todo", "in_progress", "done"]
    private let columnLabels: [String: String] = [
        "backlog": "Backlog",
        "todo": "Todo",
        "in_progress": "In Progress",
        "done": "Done"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(columns, id: \.self) { status in
                    boardColumn(status: status)
                }
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS)
        }
        .refreshable { await vm.refresh() }
        .overlay {
            if vm.isLoading && vm.tasks.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
            }
        }
        .sheet(item: $selectedTask) { task in
            NavigationStack {
                TaskDetailView(vm: vm, task: task)
            }
        }
        .confirmationDialog("Move to", isPresented: .init(
            get: { moveTask != nil },
            set: { if !$0 { moveTask = nil } }
        )) {
            if let task = moveTask {
                ForEach(columns.filter { $0 != task.status }, id: \.self) { status in
                    Button(columnLabels[status] ?? status) {
                        Task { await vm.updateStatus(taskId: task.id, status: status) }
                        moveTask = nil
                    }
                }
                Button("Cancelled") {
                    Task { await vm.updateStatus(taskId: task.id, status: "cancelled") }
                    moveTask = nil
                }
                Button("Cancel", role: .cancel) { moveTask = nil }
            }
        }
    }

    // MARK: - Column

    private func boardColumn(status: String) -> some View {
        let items = vm.tasksForStatus(status)

        return VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack(spacing: 6) {
                Image(systemName: TaskTrackerViewModel.statusIcon(status))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(columnLabels[status] ?? status)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text("\(items.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.bg)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        BoardCard(task: item)
                            .onTapGesture { selectedTask = item }
                            .onLongPressGesture { moveTask = item }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, Theme.paddingS)
            }

            if items.isEmpty {
                Text("No tasks")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.paddingL)
            }
        }
        .frame(width: 220)
        .background(Theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

// MARK: - Board Card

struct BoardCard: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Priority strip
            if let color = TaskTrackerViewModel.priorityColor(task.priority) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(height: 3)
            }

            // Title
            Text(task.title)
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.top, task.priority == "none" ? 8 : 2)

            // Labels
            if !task.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.labels.prefix(2), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.accentDim)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 10)
            }

            // Footer: assignee + due date
            HStack(spacing: 6) {
                Image(systemName: task.assignee == "agent" ? "cpu" : "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)

                if task.agentCanDo {
                    Text("AI")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }

                Spacer()

                if let due = task.dueDate {
                    let overdue = TaskTrackerViewModel.isDueDateOverdue(due)
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(TaskTrackerViewModel.formatDueDate(due))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(overdue ? Theme.error : Theme.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}
