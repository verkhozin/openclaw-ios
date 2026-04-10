import SwiftUI

struct ProjectListView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var showNewProject = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && projects.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .background(Theme.bg)
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProject = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showNewProject) {
                NewProjectSheet { _ in
                    Task { await loadProjects() }
                }
            }
            .refreshable { await loadProjects() }
            .task { await loadProjects() }
        }
    }

    // MARK: - List

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(projects) { project in
                    NavigationLink(value: project.id) {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS)
        }
        .navigationDestination(for: String.self) { projectId in
            if let project = projects.first(where: { $0.id == projectId }) {
                ProjectDetailView(project: project)
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 36))
                .foregroundColor(Theme.textMuted)
            Text("No projects yet")
                .font(.system(.body, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Button("Create Project") { showNewProject = true }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadProjects() async {
        guard let service = makeProjectService() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let index = try await service.fetchProjectIndex()
            var loaded: [Project] = []
            for entry in index.projects {
                if let project = try? await service.fetchProject(id: entry.id) {
                    loaded.append(project)
                }
            }
            projects = loaded
        } catch {
            // Index doesn't exist yet — empty state
            projects = []
        }
    }

    private func makeProjectService() -> ProjectService? {
        guard let gwURL = GatewayService.shared.gatewayURL,
              let token = GatewayService.shared.authToken else { return nil }
        let host = gwURL.host ?? "localhost"
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        guard let baseURL = URL(string: "\(scheme)://\(host):\(port)") else { return nil }
        return ProjectService(gatewayBaseURL: baseURL, token: token)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(EntityType.project.tint)

                Text(project.name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                StatusBadge(status: project.status)
            }

            if !project.description.isEmpty {
                Text(project.description)
                    .font(.system(.caption))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(Theme.paddingM)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProjectStatus

    private var label: String {
        switch status {
        case .active:    return "Active"
        case .paused:    return "Paused"
        case .completed: return "Done"
        case .archived:  return "Archived"
        }
    }

    private var color: Color {
        switch status {
        case .active:    return Theme.success
        case .paused:    return Theme.warning
        case .completed: return .blue
        case .archived:  return Theme.textMuted
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Project Detail

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject private var gateway: GatewayService
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var navigateToChat = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingM) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
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

                    // Start chat in project context
                    Button {
                        let key = UUID().uuidString
                        sessionStore.ensureSession(key: key, title: project.name)
                        sessionStore.linkSession(key, to: project.id)
                        sessionStore.openSession(key: key)
                        navigateToChat = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 12))
                            Text("New Chat")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                .padding(Theme.paddingM)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // Sessions
                let linkedSessions = sessionStore.sessions(for: project.id)
                if !linkedSessions.isEmpty {
                    sectionHeader("Sessions", icon: "bubble.left")
                    ForEach(linkedSessions) { session in
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                            Text(session.title)
                                .font(.system(.subheadline))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if session.unreadCount > 0 {
                                Text("\(session.unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.error)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, Theme.paddingM)
                        .padding(.vertical, Theme.paddingS)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    }
                }

                // Paths info
                sectionHeader("Workspace", icon: "folder")
                VStack(alignment: .leading, spacing: 4) {
                    pathRow("Tasks", path: "projects/\(project.id)/tasks/")
                    pathRow("Files", path: "projects/\(project.id)/files/")
                }
                .padding(Theme.paddingM)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS)
        }
        .background(Theme.bg)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToChat) {
            ChatScreenView()
                .navigationBarHidden(true)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, Theme.paddingS)
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
}
