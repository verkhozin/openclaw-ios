import SwiftUI

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case home, workspace, command, chat, agent

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .workspace: return "rectangle.grid.2x2.fill"
        case .command: return "bolt.fill"
        case .chat: return "bubble.left.fill"
        case .agent: return "cpu.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .workspace: return "Workspace"
        case .command: return "Command"
        case .chat: return "Chat"
        case .agent: return "Agent"
        }
    }

    var isCenter: Bool { self == .command }
    static var leftTabs: [AppTab] { [.home, .workspace] }
    static var rightTabs: [AppTab] { [.chat, .agent] }
}

// MARK: - Glass Tab Bar

@available(iOS 26.0, *)
struct GlassTabBar: View {
    @Binding var selected: AppTab
    @Namespace private var glassNS

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 6) {
                ForEach(AppTab.allCases, id: \.rawValue) { tab in
                    if tab.isCenter {
                        centerButton(tab)
                    } else {
                        tabButton(tab)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .glassEffect(.regular, in: .capsule)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected == tab ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .glassEffect(
                selected == tab ? .regular.interactive() : .identity,
                in: .capsule
            )
            .glassEffectID(tab.rawValue, in: glassNS)
        }
    }

    private func centerButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive().tint(Theme.accent.opacity(0.3)), in: .circle)
                .glassEffectID(tab.rawValue, in: glassNS)
        }
    }
}

// MARK: - Gallery

struct TabBarGallery: View {
    @State private var selected: AppTab = .home

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack {
                Spacer()

                Text("Selected: \(selected.label)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if #available(iOS 26.0, *) {
                    GlassTabBar(selected: $selected)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                } else {
                    Text("Requires iOS 26")
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("Gallery") {
    TabBarGallery()
}

@available(iOS 26.0, *)
#Preview("In context") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack {
            Spacer()
            GlassTabBar(selected: .constant(.home))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
    .preferredColorScheme(.dark)
}
