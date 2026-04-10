import SwiftUI

// MARK: - Tab Bar Visibility

private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var hideTabBar: Binding<Bool> {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: PillTab = .chat
    @State private var showCommandPalette = false
    @State private var tabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content — all stacks stay alive, hidden via opacity
            ZStack {
                NavigationStack { ChatListView() }
                    .opacity(selectedTab == .chat ? 1 : 0)
                    .zIndex(selectedTab == .chat ? 1 : 0)

                NavigationStack { WorkspaceView() }
                    .opacity(selectedTab == .workspace ? 1 : 0)
                    .zIndex(selectedTab == .workspace ? 1 : 0)

                NavigationStack { DashboardView() }
                    .opacity(selectedTab == .dashboard ? 1 : 0)
                    .zIndex(selectedTab == .dashboard ? 1 : 0)

                NavigationStack { SettingsView() }
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .zIndex(selectedTab == .settings ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.hideTabBar, $tabBarHidden)

            // Tab bar
            if !tabBarHidden {
                PillTabBar(selected: $selectedTab) {
                    showCommandPalette = true
                }
                .padding(.bottom, 0)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: tabBarHidden)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showCommandPalette) {
            EntitySearchMockView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}
