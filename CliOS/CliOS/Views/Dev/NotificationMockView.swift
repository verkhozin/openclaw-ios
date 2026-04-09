import SwiftUI

/// Dev screen for testing all notification types and queue behavior.
struct NotificationMockView: View {
    @StateObject private var manager = NotificationManager.shared

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.paddingL) {
                    sectionTitle("Card Style")
                    cardButtons

                    sectionTitle("Island Style")
                    islandButtons

                    sectionTitle("Pill Style (Liquid Glass)")
                    pillButtons

                    sectionTitle("Sequences")
                    sequenceButtons

                    sectionTitle("Controls")
                    controlButtons
                }
                .padding(Theme.paddingM)
                .padding(.bottom, 80)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .notificationOverlay(manager)
        .statusBarHidden(manager.current?.style == .island && !manager.isDismissing)
    }

    // MARK: - Card style buttons

    private var cardButtons: some View {
        VStack(spacing: 10) {
            // Text only — different colors
            mockButton("Agent Update (orange)", icon: "sparkles", tint: Color(hex: "FF4D00")) {
                manager.post(.agentUpdate, title: "Agent finished task", subtitle: "PR #42 merged to main — 3 files changed, all checks passed.", style: .card)
            }

            mockButton("Task Complete (green)", icon: "checkmark.circle", tint: Theme.success) {
                manager.post(.taskComplete, title: "Deploy to staging — done", subtitle: "Build 2.4.1 deployed successfully in 47s.", style: .card)
            }

            mockButton("Cron Triggered (yellow)", icon: "clock", tint: Theme.warning) {
                manager.post(.cronTriggered, title: "Cron 'daily-report' started", subtitle: "Scheduled run — next at 09:00 tomorrow.", style: .card)
            }

            mockButton("System Info (gray)", icon: "info.circle", tint: Theme.textSecondary) {
                manager.post(.system, title: "App updated to v2.4.1", subtitle: "New: notification banners, improved task board.", style: .card)
            }

            // With buttons
            mockButton("Task Failed + buttons", icon: "xmark.circle", tint: Theme.error) {
                manager.post(.taskFailed, title: "Build failed", subtitle: "Exit code 1 — tap View Logs for details.", style: .card)
            }

            mockButton("Connection Lost (persistent)", icon: "wifi.slash", tint: Theme.error) {
                manager.post(.connectionLost, title: "Gateway disconnected", subtitle: "Attempting to reconnect...", style: .card)
            }

            mockButton("Connection Restored (green)", icon: "wifi", tint: Theme.success) {
                manager.post(.connectionRestored, title: "Connected to Gateway", subtitle: "Latency 42ms", style: .card)
            }

            // Text only, no subtitle
            mockButton("Title only (orange)", icon: "sparkles", tint: Color(hex: "FF4D00")) {
                manager.post(.agentUpdate, title: "Agent is thinking...", style: .card)
            }
        }
    }

    // MARK: - Island style buttons

    private var islandButtons: some View {
        VStack(spacing: 10) {
            // Gateway
            mockButton("Gateway Connected", icon: "wifi", tint: Theme.success) {
                manager.post(.connectionRestored, title: "Connected", subtitle: "Latency 42ms", style: .island)
            }
            mockButton("Gateway Reconnecting", icon: "arrow.triangle.2.circlepath", tint: Theme.warning) {
                manager.post(.system, title: "Reconnecting...", subtitle: "Attempt 2 of 5", style: .island)
            }
            mockButton("Gateway Disconnected", icon: "wifi.slash", tint: Theme.error) {
                manager.post(.connectionLost, title: "Disconnected", subtitle: "Check your network", style: .island)
            }

            // Agents
            mockButton("Agent Spawned", icon: "sparkles", tint: Color(hex: "A78BFA")) {
                manager.post(.agentUpdate, title: "Scout #2 spawned", subtitle: "Pipeline: lead-gen", style: .island)
            }
            mockButton("Agent Finished", icon: "checkmark.circle", tint: Theme.success) {
                manager.post(.taskComplete, title: "Engineer #1 done", subtitle: "3 files changed", style: .island)
            }
            mockButton("Agent Crashed", icon: "exclamationmark.triangle", tint: Theme.error) {
                manager.post(.taskFailed, title: "Designer #1 crashed", subtitle: "OOM — restarting", style: .island)
            }
            mockButton("Agent Queue Full", icon: "tray.full", tint: Theme.warning) {
                manager.post(.system, title: "Queue full", subtitle: "4/4 agents active", style: .island)
            }

            // Cron
            mockButton("Cron Triggered", icon: "clock", tint: Theme.warning) {
                manager.post(.cronTriggered, title: "daily-report", subtitle: "Running now", style: .island)
            }
            mockButton("Cron Skipped", icon: "clock.badge.xmark", tint: Theme.textSecondary) {
                manager.post(.system, title: "sync skipped", subtitle: "Previous still running", style: .island)
            }
            mockButton("Cron Enabled", icon: "clock.badge.checkmark", tint: Theme.success) {
                manager.post(.system, title: "backup enabled", subtitle: "Every 6h", style: .island)
            }

            // Pipeline
            mockButton("Pipeline Started", icon: "arrow.right.circle", tint: Color(hex: "60A5FA")) {
                manager.post(.agentUpdate, title: "Pipeline started", subtitle: "lead-gen → 4 stages", style: .island)
            }
            mockButton("Pipeline Completed", icon: "checkmark.circle", tint: Theme.success) {
                manager.post(.taskComplete, title: "Pipeline done", subtitle: "12 leads processed", style: .island)
            }
            mockButton("Pipeline Error", icon: "xmark.circle", tint: Theme.error) {
                manager.post(.taskFailed, title: "Pipeline failed", subtitle: "Stage: qualifier", style: .island)
            }

            // Rate limit
            mockButton("Rate Limit Hit", icon: "gauge.with.dots.needle.67percent", tint: Theme.warning) {
                manager.post(.system, title: "Rate limited", subtitle: "OpenAI — retry in 30s", style: .island)
            }

            // Git
            mockButton("Branch Created", icon: "arrow.triangle.branch", tint: Color(hex: "A78BFA")) {
                manager.post(.agentUpdate, title: "feat/notifications", subtitle: "From main", style: .island)
            }
            mockButton("Commit Pushed", icon: "arrow.up.circle", tint: Theme.success) {
                manager.post(.taskComplete, title: "Pushed 3 commits", subtitle: "feat/notifications → origin", style: .island)
            }
            mockButton("Deploy Triggered", icon: "paperplane", tint: Color(hex: "60A5FA")) {
                manager.post(.agentUpdate, title: "Deploy triggered", subtitle: "staging — v2.4.1", style: .island)
            }
        }
    }

    // MARK: - Pill style buttons

    private var pillButtons: some View {
        VStack(spacing: 10) {
            mockButton("Agent Update", icon: "sparkles", tint: Color(hex: "FF4D00")) {
                manager.post(.agentUpdate, title: "Agent finished task", subtitle: "PR #42 merged to main — all checks passed.", style: .pill)
            }

            mockButton("Task Complete", icon: "checkmark.circle.fill", tint: Theme.success) {
                manager.post(.taskComplete, title: "Deploy to staging — done", subtitle: "Build 2.4.1 deployed in 47s.", style: .pill)
            }

            mockButton("Task Failed", icon: "xmark.circle.fill", tint: Theme.error) {
                manager.post(.taskFailed, title: "Build failed", subtitle: "Exit code 1 — tap for details.", style: .pill)
            }

            mockButton("Connection Restored", icon: "wifi", tint: Theme.success) {
                manager.post(.connectionRestored, title: "Connected to Gateway", style: .pill)
            }

            mockButton("Cron Triggered", icon: "clock.fill", tint: Theme.warning) {
                manager.post(.cronTriggered, title: "Cron 'daily-report' started", subtitle: "Next at 09:00 tomorrow.", style: .pill)
            }

            mockButton("System", icon: "info.circle.fill", tint: Theme.textSecondary) {
                manager.post(.system, title: "App updated to v2.4.1", subtitle: "New: notification banners.", style: .pill)
            }
        }
    }

    // MARK: - Sequences

    private var sequenceButtons: some View {
        VStack(spacing: 10) {
            mockButton("Queue Burst (3)", icon: "3.circle.fill", tint: Color(hex: "A78BFA")) {
                manager.post(.cronTriggered, title: "Cron 'sync' started")
                manager.post(.agentUpdate, title: "Agent picked up sync task")
                manager.post(.taskComplete, title: "Sync complete — 12 records")
            }

            mockButton("Disconnect → Reconnect", icon: "arrow.triangle.2.circlepath", tint: Theme.warning) {
                manager.post(.connectionLost, title: "Gateway disconnected", subtitle: "Reconnecting...")
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        manager.post(.connectionRestored, title: "Connected to Gateway")
                    }
                }
            }
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        VStack(spacing: 10) {
            mockButton("Dismiss Current", icon: "xmark", tint: Theme.textMuted) {
                manager.dismiss()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func mockButton(
        _ title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        NotificationMockView()
    }
    .preferredColorScheme(.dark)
}
