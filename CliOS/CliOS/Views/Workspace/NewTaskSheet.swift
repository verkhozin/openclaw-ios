import SwiftUI

struct NewTaskSheet: View {
    @ObservedObject var vm: TaskTrackerViewModel
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title = ""
    @State private var desc = ""
    @State private var status = "todo"
    @State private var priority = "medium"
    @State private var isSaving = false

    private let statuses = ["backlog", "todo", "in_progress"]
    private let statusLabels: [String: String] = [
        "backlog": "Backlog", "todo": "Todo", "in_progress": "In Progress"
    ]
    private let priorities = ["urgent", "high", "medium", "low", "none"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.system(.body, weight: .medium))

                    ZStack(alignment: .topLeading) {
                        if desc.isEmpty {
                            Text("Description (optional)")
                                .foregroundColor(Theme.textMuted)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $desc)
                            .frame(minHeight: 60)
                    }
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { s in
                            Text(statusLabels[s] ?? s).tag(s)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { p in
                            HStack(spacing: 8) {
                                if let color = TaskTrackerViewModel.priorityColor(p) {
                                    Circle().fill(color).frame(width: 8, height: 8)
                                }
                                Text(p.capitalized)
                            }
                            .tag(p)
                        }
                    }
                }

                if vm.boards.count > 1 {
                    Section("Board") {
                        Picker("Board", selection: Binding(
                            get: { vm.selectedBoardId ?? "" },
                            set: { id in Task { await vm.selectBoard(id) } }
                        )) {
                            ForEach(vm.boards) { board in
                                Text(board.name).tag(board.id)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { createTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if title.isEmpty && !initialTitle.isEmpty {
                title = initialTitle
            }
        }
    }

    private func createTask() {
        isSaving = true
        let boardId = vm.selectedBoardId ?? "default"
        let now = ISO8601DateFormatter().string(from: Date())
        let id = "\(boardId)-\(Int(Date().timeIntervalSince1970))"

        let task = TaskItem(
            id: id,
            title: title.trimmingCharacters(in: .whitespaces),
            description: desc.isEmpty ? nil : desc,
            status: status,
            priority: priority,
            labels: [],
            assignee: "human",
            agentCanDo: false,
            dueDate: nil,
            createdAt: now,
            updatedAt: now
        )

        Task {
            await vm.addTask(task)
            dismiss()
        }
    }
}
