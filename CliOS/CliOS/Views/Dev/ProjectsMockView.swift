import SwiftUI

/// Dev-only view showing the Projects system with mock data.
/// Use this to preview project list, detail, creation sheet, and status badges.
struct ProjectsMockView: View {
    @State private var projects: [Project] = Self.mockProjects
    @State private var showNewProject = false
    @State private var selectedProject: Project?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingL) {

                // MARK: - Status Badges
                sectionHeader("Status Badges")
                HStack(spacing: 10) {
                    StatusBadge(status: .active)
                    StatusBadge(status: .paused)
                    StatusBadge(status: .completed)
                    StatusBadge(status: .archived)
                }

                // MARK: - Project Rows
                sectionHeader("Project List")
                ForEach(projects) { project in
                    ProjectRow(project: project)
                        .onTapGesture { selectedProject = project }
                }

                // MARK: - Create Button
                sectionHeader("Actions")
                Button {
                    showNewProject = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("New Project")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // MARK: - Detail Preview
                if let project = selectedProject {
                    sectionHeader("Detail: \(project.name)")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            StatusBadge(status: project.status)
                            Spacer()
                            Text(project.id)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        }

                        if !project.description.isEmpty {
                            Text(project.description)
                                .font(.system(.body))
                                .foregroundColor(Theme.textSecondary)
                        }

                        Divider().overlay(Theme.textMuted.opacity(0.2))

                        // Mock task summary
                        HStack(spacing: 16) {
                            taskStat("5", label: "Done", color: Theme.success)
                            taskStat("3", label: "In Progress", color: Theme.warning)
                            taskStat("4", label: "Todo", color: Theme.textSecondary)
                        }

                        Divider().overlay(Theme.textMuted.opacity(0.2))

                        // Workspace paths
                        pathRow("Tasks", path: "projects/\(project.id)/tasks/")
                        pathRow("Files", path: "projects/\(project.id)/files/")

                        Divider().overlay(Theme.textMuted.opacity(0.2))

                        // Mock linked sessions
                        Text("Linked Sessions")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)

                        ForEach(Self.mockSessionsForProject(project.id), id: \.self) { title in
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textMuted)
                                Text(title)
                                    .font(.system(.subheadline))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                            }
                        }
                    }
                    .padding(Theme.paddingM)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // MARK: - Chat Row with Project Badge
                sectionHeader("Chat Row with Badge")
                VStack(spacing: 0) {
                    mockChatRow(title: "Fix hero animation", project: "landing-v2")
                    Divider().overlay(Theme.textMuted.opacity(0.2)).padding(.leading, 60)
                    mockChatRow(title: "Debug memory leak", project: nil)
                    Divider().overlay(Theme.textMuted.opacity(0.2)).padding(.leading, 60)
                    mockChatRow(title: "Write API docs", project: "crm-bot")
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.top, Theme.paddingS)
        }
        .background(Theme.bg)
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet { project in
                projects.append(project)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, weight: .heavy))
            .foregroundColor(Theme.textMuted)
            .textCase(.uppercase)
            .padding(.top, 8)
    }

    private func taskStat(_ count: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(count)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
        }
    }

    private func pathRow(_ label: String, path: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textMuted)
        }
    }

    private func mockChatRow(title: String, project: String?) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.surface)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "cpu")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textMuted)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    if let project {
                        Text(project)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(EntityType.project.tint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(EntityType.project.tint.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()
                    Text("2h")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }

                Text("Agent response preview text here...")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, 10)
    }

    // MARK: - Mock Data

    private static let mockProjects: [Project] = {
        let now = ISO8601DateFormatter().string(from: Date())
        let weekAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-604800))
        let monthAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2592000))

        return [
            Project(
                id: "landing-v2",
                name: "Landing Redesign",
                description: "Redesign the main landing page with new hero section, testimonials, and pricing table.",
                status: .active,
                createdAt: weekAgo,
                updatedAt: now
            ),
            Project(
                id: "crm-bot",
                name: "CRM Bot",
                description: "AI agent that qualifies leads, enriches contacts, and drafts outreach emails.",
                status: .active,
                createdAt: monthAgo,
                updatedAt: weekAgo
            ),
            Project(
                id: "weekly-reports",
                name: "Weekly Reports Pipeline",
                description: "Automated weekly digest: commits, PRs, incidents, team velocity.",
                status: .paused,
                createdAt: monthAgo,
                updatedAt: monthAgo
            ),
            Project(
                id: "auth-refactor",
                name: "Auth Refactor",
                description: "",
                status: .completed,
                createdAt: monthAgo,
                updatedAt: weekAgo
            ),
        ]
    }()

    private static func mockSessionsForProject(_ id: String) -> [String] {
        switch id {
        case "landing-v2": return ["Fix hero animation", "Design review", "Mobile responsive"]
        case "crm-bot": return ["Lead qualification logic", "Email templates"]
        case "weekly-reports": return ["Setup pipeline"]
        default: return ["General discussion"]
        }
    }
}
