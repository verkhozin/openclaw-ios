import SwiftUI

// MARK: - Sub-Agent Card
//
// Chat card for sub-agent spawn events. Terminal-style monospace
// output showing what the sub-agent was tasked with.
// No status tracking, no duration — just the task log.

struct SubAgentCard: View {
    let task: String
    let agentName: String

    private let accent = Color(hex: "FF4D00")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — subtle, monospace
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text("sub-agent")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent)

                if !agentName.isEmpty {
                    Text("·")
                        .foregroundStyle(Theme.textMuted)
                    Text(agentName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .background(Theme.surface)

            // Divider
            Rectangle()
                .fill(accent.opacity(0.15))
                .frame(height: 1)

            // Task body — monospace, with left accent bar
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accent.opacity(0.4))
                    .frame(width: 2.5)

                Text(task)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.paddingM)
            .background(Theme.surface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SubAgentCard(
            task: "Research competitor pricing models and generate a comparison table for the Q2 strategy review",
            agentName: "researcher"
        )

        SubAgentCard(
            task: "Scan the codebase for unused imports and dead exports across all TypeScript files",
            agentName: ""
        )

        SubAgentCard(
            task: "Draft a cold outreach email sequence for enterprise SaaS leads in the fintech vertical, focusing on compliance pain points",
            agentName: "copywriter"
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
