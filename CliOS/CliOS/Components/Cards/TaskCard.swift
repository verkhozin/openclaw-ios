import SwiftUI

// MARK: - Data types

enum TaskSource: String {
    case linear, github, clickup, jira, asana, notion

    var label: String {
        switch self {
        case .linear: "Linear"
        case .github: "GitHub"
        case .clickup: "ClickUp"
        case .jira: "Jira"
        case .asana: "Asana"
        case .notion: "Notion"
        }
    }

    var color: Color {
        switch self {
        case .linear: Color(hex: "5E6AD2")
        case .github: Color(hex: "232925")
        case .clickup: Color(hex: "7B68EE")
        case .jira: Color(hex: "0052CC")
        case .asana: Color(hex: "F06A6A")
        case .notion: Color(hex: "2D2D2D")
        }
    }

    var icon: String {
        switch self {
        case .github: "github"
        case .linear, .clickup, .jira, .asana, .notion: ""
        }
    }

    var sfIcon: String {
        switch self {
        case .linear: "line.3.horizontal.decrease.circle"
        case .clickup: "checkmark.square"
        case .jira: "diamond"
        case .asana: "circles.hexagonpath"
        case .notion: "doc.text"
        case .github: ""
        }
    }

    var isAssetIcon: Bool { self == .github }
}

enum TaskPriority: Int {
    case urgent = 0, high, medium, low, none

    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .none: "None"
        }
    }

    var color: Color {
        switch self {
        case .urgent: Color(hex: "FF3B30")
        case .high: Color(hex: "FF9500")
        case .medium: Color(hex: "FFD60A")
        case .low: Color(hex: "34C759")
        case .none: Color(hex: "888888")
        }
    }

    var icon: String {
        switch self {
        case .urgent: "exclamationmark.2"
        case .high: "arrow.up"
        case .medium: "minus"
        case .low: "arrow.down"
        case .none: "minus"
        }
    }

    var bars: Int {
        switch self {
        case .urgent: 4
        case .high: 3
        case .medium: 2
        case .low: 1
        case .none: 0
        }
    }

}

enum TaskStatus: String {
    case backlog, todo, inProgress, done, cancelled

    var label: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .inProgress: "In Progress"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .backlog: Color(hex: "888888")
        case .todo: Color(hex: "B0B0B0")
        case .inProgress: Color(hex: "F5A623")
        case .done: Color(hex: "34C759")
        case .cancelled: Color(hex: "FF3B30")
        }
    }

    var icon: String {
        switch self {
        case .backlog: "circle.dotted"
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }
}

// MARK: - Card

struct TaskCard: View {
    let source: TaskSource
    let id: String
    let title: String
    let status: TaskStatus
    let priority: TaskPriority
    var assignee: String? = nil
    var labels: [String] = []
    var project: String? = nil

    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let badgeFont: Font = .system(size: 11, weight: .medium)
    private let idFont: Font = .custom("JetBrainsMono-Medium", size: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 5) {
                if source.isAssetIcon {
                    Image(source.icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: source.sfIcon)
                        .font(.system(size: 12))
                }

                Text(source.label)

                if let project {
                    Text("· \(project)")
                        .opacity(0.7)
                }

                Spacer()

                Text(id)
                    .font(idFont)
                    .opacity(0.7)
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(source.color)

            // Body
            VStack(alignment: .leading, spacing: 10) {
                // Title row: status icon + title + priority wave
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: status.icon)
                        .font(.system(size: 18))
                        .foregroundColor(status.color)
                        .frame(width: 22)
                        .padding(.top, 1)

                    Text(title)
                        .font(titleFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    priorityWave
                        .layoutPriority(1)
                }

                // Meta: assignee · labels
                HStack(spacing: 0) {
                    if let assignee {
                        HStack(spacing: 3) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 10))
                            Text(assignee)
                        }
                        .foregroundColor(Theme.textSecondary)
                    }

                    if !labels.isEmpty {
                        if assignee != nil { dot }
                        HStack(spacing: 4) {
                            ForEach(labels, id: \.self) { label in
                                let c = labelColor(label)
                                Text(label)
                                    .font(badgeFont)
                                    .foregroundColor(c)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(c.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
                .font(captionFont)
            }
            .padding(Theme.paddingM)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var dot: some View {
        Text(" · ")
            .fontWeight(.bold)
            .foregroundColor(Theme.textMuted)
            .font(captionFont)
    }

    private func labelColor(_ label: String) -> Color {
        let colors: [Color] = [
            Color(hex: "5E6AD2"),
            Color(hex: "E5534B"),
            Color(hex: "4285F4"),
            Color(hex: "34A853"),
            Color(hex: "A371F7"),
            Color(hex: "DB61A2")
        ]
        let hash = abs(label.hashValue)
        return colors[hash % colors.count]
    }

    // Signal bars — like wifi/cell signal, aligned at bottom
    private var priorityWave: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < priority.bars ? priority.color : Theme.border)
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
    }
}

// MARK: - Previews

#Preview("Dark") {
    ScrollView {
        VStack(spacing: 16) {
            TaskCard(
                source: .linear,
                id: "CLI-42",
                title: "WebSocket reconnect drops messages on poor network",
                status: .inProgress,
                priority: .urgent,
                assignee: "Egor",
                labels: ["bug", "p0", "gateway"],
                project: "CLiOS"
            )

            TaskCard(
                source: .github,
                id: "#128",
                title: "Add rate limiting to gateway API endpoints",
                status: .todo,
                priority: .high,
                assignee: "Alex",
                labels: ["enhancement"],
                project: "verkh-tech/api"
            )

            TaskCard(
                source: .clickup,
                id: "CU-8f2k",
                title: "Update onboarding flow copy",
                status: .done,
                priority: .low,
                labels: ["design", "copy"]
            )

            TaskCard(
                source: .jira,
                id: "PROJ-451",
                title: "Migrate user sessions to Redis",
                status: .backlog,
                priority: .medium,
                assignee: "Dima",
                project: "Backend"
            )

            TaskCard(
                source: .linear,
                id: "CLI-99",
                title: "Card protocol v2: action buttons",
                status: .cancelled,
                priority: .none
            )
        }
        .padding()
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    VStack(spacing: 16) {
        TaskCard(
            source: .linear,
            id: "CLI-42",
            title: "WebSocket reconnect drops messages",
            status: .inProgress,
            priority: .urgent,
            assignee: "Egor",
            labels: ["bug", "p0"],
            project: "CLiOS"
        )
        TaskCard(
            source: .github,
            id: "#128",
            title: "Add rate limiting to gateway API",
            status: .todo,
            priority: .high,
            assignee: "Alex",
            project: "verkh-tech/api"
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
