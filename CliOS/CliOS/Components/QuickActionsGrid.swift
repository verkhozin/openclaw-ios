import SwiftUI

struct QuickActionsGrid: View {
    // TODO: Make configurable by user
    let actions: [QuickAction] = [
        QuickAction(icon: "envelope.fill", label: "Email", prompt: "Check email and tell me if anything urgent"),
        QuickAction(icon: "chart.bar.fill", label: "Status", prompt: "Give me a quick status update"),
        QuickAction(icon: "hammer.fill", label: "Build", prompt: "Run the next pending task from the queue"),
        QuickAction(icon: "questionmark.circle.fill", label: "What's next?", prompt: "What should I focus on right now?"),
    ]
    
    @EnvironmentObject var gateway: GatewayService
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Theme.paddingS) {
            ForEach(actions) { action in
                Button {
                    gateway.sendMessage(action.prompt)
                } label: {
                    HStack {
                        Image(systemName: action.icon)
                            .foregroundColor(Theme.accent)
                        Text(action.label)
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(Theme.paddingM)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                }
            }
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let prompt: String
}
