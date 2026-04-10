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

// MARK: - Pill Tab Bar

struct PillTabBar: View {
    @Binding var selected: PillTab
    var onCommandTap: () -> Void = {}

    @Namespace private var pillNS
    @State private var tabFrames: [PillTab: CGRect] = [:]
    @State private var isDragging = false

    private let pillBg = Color(hex: "1C1C1E")
    private let selectedBg = Color.white
    private let iconInactive = Color.white.opacity(0.5)
    private let commandBg = Color(hex: "2C2C2E")
    private let barHeight: CGFloat = 54
    private let pillSpace = "pillCoord"

    var body: some View {
        HStack(spacing: 12) {
            // Main pill: all tabs — single gesture handles both tap and drag
            HStack(spacing: 4) {
                ForEach(PillTab.allCases) { tab in
                    tabLabel(tab)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: TabFrameKey.self,
                                    value: [tab: geo.frame(in: .named(pillSpace))]
                                )
                            }
                        )
                }
            }
            .padding(6)
            .background(pillBg, in: Capsule())
            .coordinateSpace(name: pillSpace)
            .onPreferenceChange(TabFrameKey.self) { tabFrames = $0 }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(pillSpace))
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        let hit = tabFrames.first { $0.value.insetBy(dx: -8, dy: -4).contains(value.location) }?.key
                        if let hit, hit != selected {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selected = hit
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Command button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onCommandTap()
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: barHeight + 12, height: barHeight + 12)
                    .background(commandBg, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .animation(isDragging ? .interactiveSpring(response: 0.25, dampingFraction: 0.7) : .spring(response: 0.35, dampingFraction: 0.8), value: selected)
    }

    private func tabLabel(_ tab: PillTab) -> some View {
        let isSelected = selected == tab

        return HStack(spacing: 7) {
            Image(systemName: tab.icon)
                .font(.system(size: 17, weight: .semibold))

            if isSelected {
                Text(tab.label)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize()
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(isSelected ? Color.black : iconInactive)
        .padding(.horizontal, isSelected ? 16 : 16)
        .frame(height: barHeight)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                Capsule()
                    .fill(selectedBg)
                    .matchedGeometryEffect(id: "pill", in: pillNS)
            }
        }
    }
}

// MARK: - Preference Key

private struct TabFrameKey: PreferenceKey {
    static var defaultValue: [PillTab: CGRect] = [:]
    static func reduce(value: inout [PillTab: CGRect], nextValue: () -> [PillTab: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
