import SwiftUI

// MARK: - Tab Definition

enum PillTab: Int, CaseIterable, Identifiable {
    case chat, workspace, dashboard, settings

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .chat:      return "bubble.left.fill"
        case .workspace: return "folder.fill"
        case .dashboard: return "square.grid.2x2.fill"
        case .settings:  return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .chat:      return "Chats"
        case .workspace: return "Files"
        case .dashboard: return "Dash"
        case .settings:  return "Settings"
        }
    }

    static var leftTabs: [PillTab]  { [.chat, .workspace] }
    static var rightTabs: [PillTab] { [.dashboard, .settings] }
}

// MARK: - Split Pill Tab Bar

struct PillTabBar: View {
    @Binding var selected: PillTab
    var onCommandTap: () -> Void = {}

    @Namespace private var pillNS

    private let pillBg = Color(hex: "1C1C1E")
    private let selectedBg = Color.white
    private let iconInactive = Color.white.opacity(0.5)
    private let commandBg = Color(hex: "2C2C2E")

    var body: some View {
        HStack(spacing: 12) {
            // Main pill: all tabs
            HStack(spacing: 4) {
                ForEach(PillTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(5)
            .background(pillBg, in: Capsule())

            // Command button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onCommandTap()
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(commandBg, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    private func tabItem(_ tab: PillTab) -> some View {
        let isSelected = selected == tab

        return Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .semibold))

                if isSelected {
                    Text(tab.label)
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize()
                        .transition(.blurReplace)
                }
            }
            .foregroundStyle(isSelected ? Color.black : iconInactive)
            .padding(.horizontal, isSelected ? 14 : 10)
            .frame(height: 40)
            .background {
                if isSelected {
                    Capsule()
                        .fill(selectedBg)
                        .matchedGeometryEffect(id: "pill", in: pillNS)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
