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
    @State private var showDatePicker = false
    @FocusState private var titleFocused: Bool
    @FocusState private var descFocused: Bool

    private let task: TaskItem

    private let statuses = ["backlog", "todo", "in_progress", "done", "cancelled"]
    private let statusLabels: [String: String] = [
        "backlog": "Backlog", "todo": "Todo", "in_progress": "In Progress",
        "done": "Done", "cancelled": "Cancelled"
    ]
    private let priorities = ["urgent", "high", "medium", "low", "none"]
    private let priorityIcons: [String: String] = [
        "urgent": "exclamationmark.3",
        "high": "exclamationmark.2",
        "medium": "equal",
        "low": "minus",
        "none": "minus"
    ]

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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Header bar
                headerBar

                // MARK: - Title
                TextField("Task title", text: $title, axis: .vertical)
                    .font(.system(.title2, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .focused($titleFocused)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                // MARK: - Description
                ZStack(alignment: .topLeading) {
                    if desc.isEmpty && !descFocused {
                        Text("Add description…")
                            .font(.system(.body))
                            .foregroundColor(Theme.textMuted)
                            .padding(.leading, 24)
                            .padding(.top, 9)
                    }
                    TextEditor(text: $desc)
                        .font(.system(.body))
                        .foregroundColor(Theme.textSecondary)
                        .focused($descFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                divider

                // MARK: - Properties
                VStack(spacing: 0) {
                    propertyRow(label: "Status", icon: "circle.dotted") {
                        statusPicker
                    }

                    propertyRow(label: "Priority", icon: "flag") {
                        priorityPicker
                    }

                    propertyRow(label: "Assignee", icon: "person") {
                        assigneePicker
                    }

                    propertyRow(label: "Labels", icon: "tag") {
                        labelsRow
                    }

                    propertyRow(label: "Due date", icon: "calendar") {
                        dueDateRow
                    }

                    if agentCanDo || assignee == "agent" {
                        propertyRow(label: "Agent can do", icon: "cpu") {
                            agentToggle
                        }
                    }
                }

                divider

                // MARK: - Metadata
                VStack(spacing: 0) {
                    metaRow(label: "Created", value: formatTimestamp(task.createdAt))
                    metaRow(label: "Updated", value: formatTimestamp(task.updatedAt))
                    metaRow(label: "ID", value: task.id, mono: true)
                }
                .padding(.bottom, 20)

                // Error
                if let saveError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text(saveError)
                            .font(.system(.caption))
                    }
                    .foregroundColor(Theme.error)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.error)
                    .lineLimit(1)
            }

            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 60, height: 32)
                } else {
                    Text("Save")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(hasChanges ? .white : Theme.textMuted)
                        .frame(width: 60, height: 32)
                        .background(hasChanges ? Theme.accent : Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .disabled(!hasChanges || title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Property row template

    private func propertyRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 18)
                Text(label)
                    .font(.system(.subheadline))
                    .foregroundColor(Theme.textMuted)
            }
            .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 40)
    }

    // MARK: - Status

    private var statusPicker: some View {
        Menu {
            ForEach(statuses, id: \.self) { s in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { status = s }
                } label: {
                    Label(statusLabels[s] ?? s, systemImage: TaskTrackerViewModel.statusIcon(s))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: TaskTrackerViewModel.statusIcon(status))
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
                Text(statusLabels[status] ?? status)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var statusColor: Color {
        switch status {
        case "in_progress": return Color(hex: "F5A623")
        case "done": return Theme.success
        case "cancelled": return Theme.textMuted
        case "todo": return Color(hex: "6E7B8B")
        default: return Theme.textMuted
        }
    }

    // MARK: - Priority

    private var priorityPicker: some View {
        Menu {
            ForEach(priorities, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { priority = p }
                } label: {
                    HStack {
                        Image(systemName: priorityIcons[p] ?? "minus")
                        Text(p.capitalized)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let color = TaskTrackerViewModel.priorityColor(priority) {
                    Image(systemName: priorityIcons[priority] ?? "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                }
                Text(priority.capitalized)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Assignee

    private var assigneePicker: some View {
        Menu {
            Button { assignee = "human" } label: {
                Label("Human", systemImage: "person.fill")
            }
            Button { assignee = "agent" } label: {
                Label("Agent", systemImage: "cpu")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: assignee == "agent" ? "cpu" : "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(assignee == "agent" ? Theme.accent : Theme.textSecondary)
                Text(assignee == "agent" ? "Agent" : "Human")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Labels

    private var labelsRow: some View {
        HStack(spacing: 6) {
            ForEach(labels, id: \.self) { label in
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Button {
                        withAnimation { labels.removeAll { $0 == label } }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            // Inline add
            HStack(spacing: 4) {
                TextField("", text: $newLabel, prompt: Text("Add").foregroundColor(Theme.textMuted))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: labels.isEmpty ? 80 : 50)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { commitLabel() }

                if !newLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button { commitLabel() } label: {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Theme.border.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
    }

    // MARK: - Due date

    private var dueDateRow: some View {
        Group {
            if hasDueDate, let date = dueDate {
                let overdue = date < Calendar.current.startOfDay(for: Date())
                Button { showDatePicker = true } label: {
                    HStack(spacing: 6) {
                        Text(formatDisplayDate(date))
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundColor(overdue ? Theme.error : Theme.textPrimary)

                        Button {
                            withAnimation {
                                hasDueDate = false
                                dueDate = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(overdue ? Theme.error.opacity(0.12) : Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                Button {
                    dueDate = Date()
                    hasDueDate = true
                    showDatePicker = true
                } label: {
                    Text("Set date")
                        .font(.system(.subheadline))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Theme.border.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                }
            }
        }
    }

    // MARK: - Agent toggle

    private var agentToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { agentCanDo.toggle() }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(agentCanDo ? Theme.accent : Theme.surface)
                    .frame(width: 16, height: 16)
                    .overlay {
                        if agentCanDo {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(agentCanDo ? Theme.accent : Theme.border, lineWidth: 1.5)
                    )
                Text(agentCanDo ? "Yes" : "No")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    // MARK: - Meta row

    private func metaRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(mono ? .system(size: 11, design: .monospaced) : .system(size: 12))
                .foregroundColor(Theme.textMuted)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Theme.border.opacity(0.3))
            .frame(height: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
    }

    // MARK: - Date picker sheet

    private var datePickerSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Due date")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button("Done") { showDatePicker = false }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            DatePicker("", selection: Binding(
                get: { dueDate ?? Date() },
                set: { dueDate = $0; hasDueDate = true }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .tint(Theme.accent)
            .padding(.horizontal, 12)

            Spacer()
        }
        .background(Theme.bg)
        .presentationDetents([.medium])
    }

    // MARK: - Has changes

    private var hasChanges: Bool {
        title.trimmingCharacters(in: .whitespaces) != task.title ||
        desc != (task.description ?? "") ||
        status != task.status ||
        priority != task.priority ||
        labels != task.labels ||
        assignee != (task.assignee ?? "human") ||
        agentCanDo != task.agentCanDo ||
        dueDateChanged
    }

    private var dueDateChanged: Bool {
        let oldDate = Self.parseDueDate(task.dueDate)
        if hasDueDate != (oldDate != nil) { return true }
        if let d = dueDate, let o = oldDate {
            return !Calendar.current.isDate(d, inSameDayAs: o)
        }
        return false
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

    private func commitLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !labels.contains(trimmed) {
            withAnimation { labels.append(trimmed) }
            newLabel = ""
        }
    }

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

    private func formatDisplayDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
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
