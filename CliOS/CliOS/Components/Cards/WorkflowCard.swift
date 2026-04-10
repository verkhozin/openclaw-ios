import SwiftUI

// MARK: - Workflow Card
//
// Compact chat card for workflow events.
// Label on top, small pill with name + agent count.

struct WorkflowCard: View {
    let workflowName: String
    let agentCount: Int

    private let accent = Color(hex: "FF4D00")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKFLOW")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(accent.opacity(0.7))

            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text(workflowName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("·")
                    .foregroundStyle(Theme.textMuted)

                Text("\(agentCount) agents")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WorkflowCard(workflowName: "lead-gen", agentCount: 6)
        WorkflowCard(workflowName: "deploy-pipeline", agentCount: 4)
        WorkflowCard(workflowName: "data-sync", agentCount: 3)
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
