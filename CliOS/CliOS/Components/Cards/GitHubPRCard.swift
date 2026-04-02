import SwiftUI

enum PRStatus: String {
    case open, merged, closed

    var label: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .open: Theme.success
        case .merged: Color(hex: "A371F7")
        case .closed: Theme.error
        }
    }

    var icon: String {
        switch self {
        case .open: "arrow.triangle.pull"
        case .merged: "arrow.triangle.merge"
        case .closed: "xmark.circle"
        }
    }
}

enum CIStatus: String {
    case passed, failed, running

    var label: String {
        switch self {
        case .passed: "Passed"
        case .failed: "Failed"
        case .running: "Running"
        }
    }

    var color: Color {
        switch self {
        case .passed: Theme.success
        case .failed: Theme.error
        case .running: Theme.warning
        }
    }

    var icon: String {
        switch self {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .running: "arrow.triangle.2.circlepath"
        }
    }
}

struct GitHubPRCard: View {
    let number: Int
    let title: String
    let status: PRStatus
    let author: String
    let repo: String
    let branch: String
    let targetBranch: String
    let ci: CIStatus
    let additions: Int
    let deletions: Int

    // Typography: 3 levels only
    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let diffFont: Font = .custom("JetBrainsMono-Medium", size: 11)
    private let badgeFont: Font = .system(size: 11, weight: .medium)

    private let githubGray = Color(hex: "232925")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored header bar
            HStack(alignment: .center, spacing: 5) {
                Image("github")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .offset(y: -1)

                Text("Pull Request")

                Text("#\(number)")
                    .opacity(0.7)

                Spacer()
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(githubGray)

            // Card body
            VStack(alignment: .leading, spacing: 8) {
                // Title + diff on first line
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(titleFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    HStack(spacing: 3) {
                        Text("+\(additions)")
                            .foregroundColor(Theme.success)
                        Text("-\(deletions)")
                            .foregroundColor(Theme.error)
                    }
                    .font(diffFont)
                    .layoutPriority(1)
                }

                // Branch: source → target
                HStack(spacing: 4) {
                    Image("git-branch")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 11, height: 11)
                        .foregroundColor(Theme.textMuted)

                    Text(branch)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                    Text(targetBranch)
                }
                .font(captionFont)
                .foregroundColor(Theme.textSecondary)

                // Footer: badges ... author · repo
                HStack(spacing: 6) {
                    badge(status.label, icon: status.icon, color: status.color)
                    badge("CI: \(ci.label)", icon: ci.icon, color: ci.color)

                    Spacer()

                    HStack(spacing: 3) {
                        Text(author)
                        Text("·").fontWeight(.bold)
                        Text(repo)
                    }
                    .font(captionFont)
                    .foregroundColor(Theme.textMuted)
                }
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

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(badgeFont)
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview("Dark") {
    VStack(spacing: 16) {
        GitHubPRCard(
            number: 128,
            title: "Fix hero animation on mobile viewport",
            status: .open,
            author: "egor",
            repo: "verkh-tech/site",
            branch: "fix/hero",
            targetBranch: "main",
            ci: .passed,
            additions: 42,
            deletions: 8
        )
        GitHubPRCard(
            number: 97,
            title: "Refactor auth middleware to support refresh tokens",
            status: .merged,
            author: "alex",
            repo: "verkh-tech/api",
            branch: "feat/refresh-tokens",
            targetBranch: "develop",
            ci: .passed,
            additions: 156,
            deletions: 43
        )
        GitHubPRCard(
            number: 64,
            title: "WIP: migrate database schema to v3",
            status: .closed,
            author: "dima",
            repo: "verkh-tech/core",
            branch: "chore/db-v3",
            targetBranch: "main",
            ci: .failed,
            additions: 8,
            deletions: 220
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    VStack(spacing: 16) {
        GitHubPRCard(
            number: 128,
            title: "Fix hero animation on mobile viewport",
            status: .open,
            author: "egor",
            repo: "verkh-tech/site",
            branch: "fix/hero",
            targetBranch: "main",
            ci: .passed,
            additions: 42,
            deletions: 8
        )
        GitHubPRCard(
            number: 97,
            title: "Refactor auth middleware to support refresh tokens",
            status: .merged,
            author: "alex",
            repo: "verkh-tech/api",
            branch: "feat/refresh-tokens",
            targetBranch: "develop",
            ci: .running,
            additions: 156,
            deletions: 43
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
