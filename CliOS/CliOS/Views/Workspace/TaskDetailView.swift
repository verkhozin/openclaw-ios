import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var vm: TaskTrackerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var desc: String
    @State private var status: String
    @State private var priority: String
    @State private var labels: [String]
    @State private var assignee: String
    @State private var agentCanDo: Bool
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool

    @State private var newLabel = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private let task: TaskItem

    private let statuses = ["backlog", "todo", "in_progress", "done", "cancelled"]
    private let statusLabels: [String: String] = [
        "backlog": "Backlog", "todo": "Todo", "in_progress": "In Progress",
        "done": "Done", "cancelled": "Cancelled"
    ]
    private let priorities = ["urgent", "high", "medium", "low", "none"]

    init(vm: TaskTrackerViewModel, task: TaskItem) {
        self.vm = vm
        self.task = task
        _title = State(initialValue: task.title)
        _desc = State(initialValue: task.description ?? "")
        _status = State(initialValue: task.status)
        _priority = State(initialValue: task.priority)
        _labels = State(initialValue: task.labels)
        _assignee = State(initialValue: task.assignee ?? "human")
        _agentCanDo = State(initialValue: task.agentCanDo)

        let parsed = Self.parseDueDate(task.dueDate)
        _dueDate = State(initialValue: parsed)
        _hasDueDate = State(initialValue: parsed != nil)
    }

    var body: some View {
        Form {
            // Title & Description
            Section {
                TextField("Title", text: $title)
                    .font(.system(.body, weight: .medium))

                ZStack(alignment: .topLeading) {
                    if desc.isEmpty {
                        Text("Description")
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $desc)
                        .frame(minHeight: 80)
                }
            }

            // Status
            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(statuses, id: \.self) { s in
                        Label(statusLabels[s] ?? s, systemImage: TaskTrackerViewModel.statusIcon(s))
                            .tag(s)
                    }
                }
                .pickerStyle(.menu)
            }

            // Priority
            Section("Priority") {
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
                .pickerStyle(.menu)
            }

            // Labels
            Section("Labels") {
                ForEach(labels, id: \.self) { label in
                    HStack {
                        Text(label)
                            .font(.system(.subheadline))
                        Spacer()
                        Button {
                            labels.removeAll { $0 == label }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }

                HStack {
                    TextField("Add label", text: $newLabel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        let trimmed = newLabel.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !labels.contains(trimmed) {
                            labels.append(trimmed)
                            newLabel = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accent)
                    }
                    .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            // Assignee
            Section("Assignee") {
                Picker("Assignee", selection: $assignee) {
                    Label("Human", systemImage: "person.fill").tag("human")
                    Label("Agent", systemImage: "cpu").tag("agent")
                }
                .pickerStyle(.segmented)

                Toggle("Agent can do", isOn: $agentCanDo)
            }

            // Due Date
            Section("Due Date") {
                Toggle("Has due date", isOn: $hasDueDate)

                if hasDueDate {
                    DatePicker("Date", selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ), displayedComponents: .date)
                }
            }

            // Error
            if let saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.error)
                        .font(.system(.subheadline))
                }
            }

            // Timestamps
            Section("Info") {
                LabeledContent("Created", value: formatTimestamp(task.createdAt))
                LabeledContent("Updated", value: formatTimestamp(task.updatedAt))
                LabeledContent("ID", value: task.id)
                    .font(Theme.fontMonoSmall)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        let dueDateStr: String? = hasDueDate ? formatDate(dueDate ?? Date()) : nil
        var updated = task
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.description = desc.isEmpty ? nil : desc
        updated.status = status
        updated.priority = priority
        updated.labels = labels
        updated.assignee = assignee
        updated.agentCanDo = agentCanDo
        updated.dueDate = dueDateStr
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())

        Task {
            saveError = nil
            let ok = await vm.updateTask(updated)
            isSaving = false
            if ok {
                dismiss()
            } else {
                saveError = vm.error ?? "Failed to save"
            }
        }
    }

    // MARK: - Helpers

    private static func parseDueDate(_ str: String?) -> Date? {
        guard let str else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: str) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        return iso.date(from: str)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private func formatTimestamp(_ str: String) -> String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: str) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
        return str
    }
}
