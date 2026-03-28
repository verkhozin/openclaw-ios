import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var gateway: GatewayService
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.paddingM) {
                    // Usage rings
                    UsageCard(
                        sessionPercent: gateway.status.sessionPercent,
                        weeklyPercent: gateway.status.weeklyPercent
                    )
                    
                    // Quick actions
                    QuickActionsGrid()
                    
                    // Active tasks summary
                    let activeTasks = gateway.tasks.filter { $0.status == .running }
                    if !activeTasks.isEmpty {
                        ActiveTasksCard(tasks: activeTasks)
                    }
                    
                    // TODO: Morning card
                    // TODO: Cron timeline
                }
                .padding(Theme.paddingM)
            }
            .background(Theme.bg)
            .navigationTitle("Dashboard")
        }
    }
}
