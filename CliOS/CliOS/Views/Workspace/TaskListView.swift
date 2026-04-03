import SwiftUI

struct TaskListView: View {
    @ObservedObject var vm: TaskTrackerViewModel
    @State private var expandedSections: Set<String> = ["in_progress", "todo"]
    @State private var selectedTask: TaskItem?
    @State private var taskToDelete: TaskItem?
    @State private var showDeleteConfirm = false

    private let sectionOrder = ["in_progress", "todo", "backlog", "done", "cancelled"]
    private let sectionLabels: [String: String] = [
        "in_progress": "In Progress",
        "todo": "Todo",
        "backlog": "Backlog",
        "done": "Done",
        "cancelled": "Cancelled"
    ]

    var body: some View {
        List {
            ForEach(sectionOrder, id: \.self) { status in
                let items = vm.tasksForStatus(status)
                if !items.isEmpty {
                    taskSection(status: status, items: items)
                }
            }

            if vm.tasks.isEmpty && !vm.isLoading {
                Section {
                    emptyState
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    Task { await vm.deleteTask(taskId: task.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(taskToDelete?.title ?? "")\"?")
        }
    }

    // MARK: - Section

    private func taskSection(status: String, items: [TaskItem]) -> some View {
        Section {
            if expandedSections.contains(status) {
                ForEach(items) { item in
                    TaskItemRow(task: item)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTask = item }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                taskToDelete = item
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if let next = vm.nextStatus(for: item.status) {
                                Button {
                                    Task { await vm.updateStatus(taskId: item.id, status: next) }
                                } label: {
                                    Label(sectionLabels[next] ?? next, systemImage: TaskTrackerViewModel.statusIcon(next))
                                }
                                .tint(Theme.success)
                            }
                        }
                        .listRowBackground(Theme.surface)
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(status) {
                        expandedSections.remove(status)
                    } else {
                        expandedSections.insert(status)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expandedSections.contains(status) ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 12)

                    Image(systemName: TaskTrackerViewModel.statusIcon(status))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(sectionLabels[status] ?? status)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(nil)

                    Text("\(items.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.surface)
                        .clipShape(Capsule())

                    Spacer()
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.textMuted)
                Text("No tasks yet")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.vertical, Theme.paddingL)
            Spacer()
        }
    }
}

// MARK: - Task Item Row

struct TaskItemRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 10) {
            // Priority strip
            if let color = TaskTrackerViewModel.priorityColor(task.priority) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 36)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .strikethrough(task.status == "done" || task.status == "cancelled",
                                  color: Theme.textMuted)

                // Labels
                if !task.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.labels.prefix(3), id: \.self) { label in
                            Text(label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accentDim)
                                .clipShape(Capsule())
                        }
                        if task.labels.count > 3 {
                            Text("+\(task.labels.count - 3)")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }
            }

            Spacer()

            // Right side: due date + assignee
            HStack(spacing: 8) {
                if let due = task.dueDate {
                    let overdue = TaskTrackerViewModel.isDueDateOverdue(due)
                    Text(TaskTrackerViewModel.formatDueDate(due))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(overdue ? Theme.error : Theme.textMuted)
                }

                // Assignee icon
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: task.assignee == "agent" ? "cpu" : "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    if task.agentCanDo {
                        Text("AI")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 1)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .offset(x: 6, y: 4)
                    }
                }
                .frame(width: 24, height: 20)
            }
        }
        .padding(.vertical, 2)
    }
}
