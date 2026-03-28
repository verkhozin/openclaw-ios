import SwiftUI

struct TaskQueueView: View {
    @EnvironmentObject var gateway: GatewayService
    
    var body: some View {
        NavigationStack {
            List {
                Section("Running") {
                    ForEach(gateway.tasks.filter { $0.status == .running }) { task in
                        TaskRow(task: task)
                    }
                }
                
                Section("Recent") {
                    ForEach(gateway.tasks.filter { $0.status != .running }) { task in
                        TaskRow(task: task)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Tasks")
        }
    }
}

struct TaskRow: View {
    let task: AgentTask
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.label)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(task.model.replacingOccurrences(of: "anthropic/", with: ""))
                        .font(Theme.fontMonoSmall)
                        .foregroundColor(Theme.textMuted)
                    
                    Text(task.runtimeFormatted)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                    
                    if let tokens = task.totalTokens {
                        Text("\(tokens / 1000)k tok")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            if task.status == .running {
                ProgressView()
                    .tint(Theme.accent)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.surface)
        // TODO: Swipe to kill
    }
    
    private var statusColor: Color {
        switch task.status {
        case .running: return Theme.accent
        case .done: return Theme.success
        case .failed: return Theme.error
        case .killed: return Theme.textMuted
        }
    }
}
