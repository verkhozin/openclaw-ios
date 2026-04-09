import SwiftUI

// MARK: - Mock data

private let mockEntities: [EntityItem] = [
    // Files
    EntityItem(id: "file:src/App.swift", type: .file, name: "App.swift", path: "src/App.swift", subtitle: "2.4 KB", icon: "swift"),
    EntityItem(id: "file:src/Theme.swift", type: .file, name: "Theme.swift", path: "src/Theme.swift", subtitle: "1.1 KB", icon: "paintbrush"),
    EntityItem(id: "file:src/GatewayService.swift", type: .file, name: "GatewayService.swift", path: "src/Services/GatewayService.swift", subtitle: "28 KB", icon: "doc"),
    EntityItem(id: "file:README.md", type: .file, name: "README.md", path: "README.md", subtitle: "540 B", icon: "doc.text"),
    // Tasks
    EntityItem(id: "task:12", type: .task, name: "Fix WebSocket reconnect", path: "backlog/12", subtitle: "in progress · high", icon: "circle.dotted"),
    EntityItem(id: "task:7", type: .task, name: "Add push notifications", path: "backlog/7", subtitle: "todo · medium", icon: "circle"),
    EntityItem(id: "task:3", type: .task, name: "Migrate to async/await", path: "backlog/3", subtitle: "done · low", icon: "checkmark.circle.fill"),
    // Sessions
    EntityItem(id: "session:abc", type: .session, name: "Refactor auth flow", path: "abc", subtitle: "Let me update the token refresh…", icon: "bubble.left.fill"),
    EntityItem(id: "session:def", type: .session, name: "Debug crash on launch", path: "def", subtitle: "The issue was a nil unwrap in…", icon: "bubble.left"),
    // Agents
    EntityItem(id: "agent:scout", type: .agent, name: "scout", path: "scout", subtitle: "running · gpt-4o", icon: "bolt.fill"),
    EntityItem(id: "agent:main", type: .agent, name: "main", path: "main", subtitle: "claude-sonnet-4-20250514", icon: "cpu"),
    // Crons
    EntityItem(id: "cron:backup", type: .cron, name: "Daily backup", path: "backup", subtitle: "0 3 * * *", icon: "clock.fill"),
    EntityItem(id: "cron:health", type: .cron, name: "Health check", path: "health", subtitle: "*/5 * * * *", icon: "clock.fill"),
    // Branches
    EntityItem(id: "branch:feat/search", type: .branch, name: "feat/search", path: "feat/search", subtitle: "3 commits ahead", icon: "arrow.triangle.branch"),
    EntityItem(id: "branch:main", type: .branch, name: "main", path: "main", subtitle: "up to date", icon: "arrow.triangle.branch"),
]

// MARK: - Mock View

struct EntitySearchMockView: View {
    @State private var query = ""
    @State private var selectedType: EntityType? = nil
    @FocusState private var focused: Bool

    private var filtered: [EntityItem] {
        var items = mockEntities
        if let type = selectedType {
            items = items.filter { $0.type == type }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(q) ||
                $0.subtitle.lowercased().contains(q)
            }
        }
        return items
    }

    private var groupedResults: [(EntityType, [EntityItem])] {
        let dict = Dictionary(grouping: filtered, by: \.type)
        return EntityType.allCases.compactMap { type in
            guard let items = dict[type], !items.isEmpty else { return nil }
            return (type, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            filterBar
            Divider().overlay(.white.opacity(0.08))
            resultsList
        }
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textMuted)

            TextField("Search everything…", text: $query)
                .font(.system(size: 17))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, 14)
    }

    // MARK: - Type filter chips

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil)
                ForEach(EntityType.allCases, id: \.self) { type in
                    filterChip(label: type.label, type: type, icon: type.icon)
                }
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(label: String, type: EntityType?, icon: String? = nil) -> some View {
        let isActive = selectedType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.05),
                in: Capsule()
            )
            .foregroundStyle(isActive ? .white : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollView {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedResults, id: \.0) { type, items in
                        Section {
                            ForEach(items) { item in
                                entityRow(item)
                            }
                        } header: {
                            sectionHeader(type)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ type: EntityType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(type.tint)
            Text(type.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Spacer()
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func entityRow(_ item: EntityItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(item.type.tint)
                .frame(width: 30, height: 30)
                .background(item.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.type.label.dropLast(item.type.label.hasSuffix("s") ? 1 : 0))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.12))
            Text("No results")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    EntitySearchMockView()
}
