import SwiftUI

struct GitCommitCard: View {
    let gitType: String    // "commit", "branch", "deploy"
    let branch: String
    let sourceBranch: String
    let commits: Int
    let deployTarget: String

    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let badgeFont: Font = .system(size: 11, weight: .medium)

    private var headerColor: Color {
        switch gitType {
        case "deploy": return Color(hex: "F78166")
        case "branch": return Color(hex: "A371F7")
        default:       return Color(hex: "3FB950")
        }
    }

    private var headerTitle: String {
        switch gitType {
        case "deploy": return "Deploy"
        case "branch": return "Branch"
        default:       return commits == 1 ? "Commit" : "\(commits) Commits"
        }
    }

    private var headerIcon: String {
        switch gitType {
        case "deploy": return "arrow.up.circle.fill"
        case "branch": return "arrow.triangle.branch"
        default:       return "arrow.triangle.merge"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 5) {
                Image(systemName: headerIcon)
                    .font(.system(size: 12, weight: .semibold))

                Text(headerTitle)

                Spacer()
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .background(headerColor)

            // Body
            VStack(alignment: .leading, spacing: 8) {
                // Branch info
                HStack(spacing: 4) {
                    Image("git-branch")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 11, height: 11)
                        .foregroundColor(Theme.textMuted)

                    Text(branch)
                        .font(titleFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }

                if gitType != "branch" {
                    // Source branch
                    HStack(spacing: 4) {
                        Text(sourceBranch)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                        Text(branch)
                    }
                    .font(captionFont)
                    .foregroundColor(Theme.textSecondary)
                }

                // Footer badges
                HStack(spacing: 6) {
                    badge(gitType, color: headerColor)

                    if gitType == "commit" {
                        badge("\(commits) commit\(commits == 1 ? "" : "s")",
                              icon: "number", color: Theme.textSecondary)
                    }

                    if !deployTarget.isEmpty {
                        badge(deployTarget, icon: "server.rack", color: Color(hex: "F78166"))
                    }
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

    private func badge(_ text: String, icon: String? = nil, color: Color) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
            }
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

#Preview {
    VStack(spacing: 16) {
        GitCommitCard(
            gitType: "commit",
            branch: "feat/notifications",
            sourceBranch: "main",
            commits: 5,
            deployTarget: ""
        )
        GitCommitCard(
            gitType: "branch",
            branch: "feat/new-feature",
            sourceBranch: "main",
            commits: 0,
            deployTarget: ""
        )
        GitCommitCard(
            gitType: "deploy",
            branch: "feat/notifications",
            sourceBranch: "main",
            commits: 3,
            deployTarget: "staging"
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
