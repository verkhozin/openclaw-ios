import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var selectedSection: Section = .files

    enum Section: String, CaseIterable {
        case tasks = "Tasks"
        case files = "Files"
        case memory = "Memory"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with segment picker
            VStack(spacing: 12) {
                HStack {
                    Text("Workspace")
                        .font(Theme.fontTitle)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }

                Picker("Section", selection: $selectedSection) {
                    ForEach(Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.top, Theme.paddingM)
            .padding(.bottom, Theme.paddingS)
            .background(Theme.bg)

            // Content
            switch selectedSection {
            case .tasks:
                TaskTrackerView()
            case .files:
                FileExplorerView()
            case .memory:
                memoryPlaceholder
            }
        }
        .background(Theme.bg)
    }

    private var memoryPlaceholder: some View {
        VStack(spacing: Theme.paddingM) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundColor(Theme.textMuted)
            Text("Agent Memory")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
            Text("Coming soon")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Workspace — Files") {
    WorkspaceView()
        .environmentObject(GatewayService.shared)
        .preferredColorScheme(.dark)
}

/// Extracted task list content (no NavigationStack wrapper — WorkspaceView doesn't need nested stacks).
struct TaskQueueContent: View {
    @EnvironmentObject var gateway: GatewayService

    var body: some View {
        List {
            let running = gateway.tasks.filter { $0.status == .running }
            let recent = gateway.tasks.filter { $0.status != .running }

            if !running.isEmpty {
                Section("Running") {
                    ForEach(running) { task in
                        TaskRow(task: task)
                    }
                }
            }

            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(recent) { task in
                        TaskRow(task: task)
                    }
                }
            }

            if gateway.tasks.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Task row used by TaskQueueContent

private struct TaskRow: View {
    let task: AgentTask

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.status == .running ? Theme.accent : (task.status == .done ? .green : .red))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.label)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(task.model) · \(task.runtimeFormatted)")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textMuted)
            }

            Spacer()

            Text(task.status.rawValue)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.vertical, 4)
    }
}
