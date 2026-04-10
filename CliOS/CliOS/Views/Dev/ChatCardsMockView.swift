import SwiftUI

/// Dev view to preview WorkflowCard and SubAgentCard designs.
struct ChatCardsMockView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                sectionHeader("WORKFLOW CARDS")

                WorkflowCard(workflowName: "lead-gen", agentCount: 6)
                WorkflowCard(workflowName: "deploy-pipeline", agentCount: 4)
                WorkflowCard(workflowName: "data-sync", agentCount: 3)

                sectionHeader("SUB-AGENT CARDS")

                SubAgentCard(
                    task: "Research competitor pricing models and generate a comparison table for the Q2 strategy review",
                    agentName: "researcher"
                )

                SubAgentCard(
                    task: "Scan the codebase for unused imports and dead exports across all TypeScript files",
                    agentName: ""
                )

                SubAgentCard(
                    task: "Draft a cold outreach email sequence for enterprise SaaS leads in the fintech vertical, focusing on compliance pain points and regulatory deadlines",
                    agentName: "copywriter"
                )

                sectionHeader("GIT CARD (reference)")

                GitCommitCard(
                    gitType: "commit",
                    branch: "feat/notifications",
                    sourceBranch: "main",
                    commits: 3,
                    deployTarget: ""
                )

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Chat Cards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        ChatCardsMockView()
    }
    .preferredColorScheme(.dark)
}
