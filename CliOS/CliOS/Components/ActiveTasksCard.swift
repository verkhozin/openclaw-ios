import SwiftUI

struct ActiveTasksCard: View {
    let tasks: [AgentTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingS) {
            Text("Active")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
            
            ForEach(tasks) { task in
                HStack {
                    ProgressView()
                        .tint(Theme.accent)
                        .scaleEffect(0.7)
                    
                    Text(task.label)
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(task.runtimeFormatted)
                        .font(Theme.fontMonoSmall)
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(Theme.paddingM)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
