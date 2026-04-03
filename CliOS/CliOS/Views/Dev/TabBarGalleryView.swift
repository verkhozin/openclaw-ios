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

// MARK: - Gallery

struct TabBarGallery: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Text("Tab Bar Gallery")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("Gallery") {
    TabBarGallery()
}
