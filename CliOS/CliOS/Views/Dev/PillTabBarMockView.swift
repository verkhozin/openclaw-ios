import SwiftUI

struct PillTabBarMockView: View {
    @State private var selected: PillTab = .chat
    @State private var showCommand = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Group {
                    switch selected {
                    case .chat:
                        mockPage(icon: "bubble.left.fill", title: "Chats")
                    case .workspace:
                        mockPage(icon: "folder.fill", title: "Files")
                    case .dashboard:
                        mockPage(icon: "square.grid.2x2.fill", title: "Dashboard")
                    case .settings:
                        mockPage(icon: "gearshape.fill", title: "Settings")
                    }
                }
                .transition(.opacity)

                Spacer()

                PillTabBar(selected: $selected) {
                    showCommand = true
                }
                .padding(.bottom, 8)
            }

            // Command palette overlay
            if showCommand {
                commandOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    private func mockPage(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.15))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var commandOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showCommand = false
                    }
                }

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("Command Palette")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .background(Color(hex: "1C1C1E"), in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    PillTabBarMockView()
}
