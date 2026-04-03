import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .chat
    
    enum Tab: String {
        case chat, tasks, dashboard, settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView()
                .tabItem {
                    Image(systemName: "bubble.left.fill")
                    Text("Chats")
                }
                .tag(Tab.chat)
            
            TaskQueueView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Tasks")
                }
                .tag(Tab.tasks)
            
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }
                .tag(Tab.dashboard)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
    }
}
