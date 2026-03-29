import SwiftUI

struct ConnectionTestView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var testMessage = ""
    @State private var showUnpairConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader

            Divider().background(Theme.border)

            // Log area
            logView

            Divider().background(Theme.border)

            // Actions
            actionBar
        }
        .background(Theme.bg)
        .navigationTitle("Connection Test")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status header

    private var statusHeader: some View {
        VStack(spacing: Theme.paddingS) {
            HStack(spacing: Theme.paddingS) {
                Circle()
                    .fill(gateway.status.isConnected ? Theme.success : Theme.error)
                    .frame(width: 12, height: 12)

                Text(gateway.status.isConnected ? "Connected" : "Disconnected")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            if let url = gateway.gatewayURL {
                HStack {
                    Text(url.absoluteString)
                        .font(Theme.fontMonoSmall)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }

            HStack(spacing: Theme.paddingM) {
                infoChip("Model", gateway.status.model)
                infoChip("Version", gateway.status.version)
                infoChip("Agent", gateway.status.agentName)
            }
        }
        .padding(Theme.paddingM)
        .background(Theme.surface)
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textMuted)
            Text(value)
                .font(Theme.fontMonoSmall)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Log view

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(gateway.connectionLog.enumerated()), id: \.offset) { idx, entry in
                        Text(entry)
                            .font(Theme.fontMonoSmall)
                            .foregroundColor(logColor(entry))
                            .id(idx)
                            .textSelection(.enabled)
                    }

                    if gateway.connectionLog.isEmpty {
                        Text("No log entries yet. Tap Connect to start.")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, Theme.paddingL)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Theme.paddingS)
            }
            .frame(maxHeight: .infinity)
            .background(Theme.bg)
            .onChange(of: gateway.connectionLog.count) {
                if let last = gateway.connectionLog.indices.last {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logColor(_ entry: String) -> Color {
        if entry.contains("Error") || entry.contains("error") || entry.contains("Failed") || entry.contains("failed") {
            return Theme.error
        }
        if entry.contains("confirmed") || entry.contains("Connected") || entry.contains("Pong") {
            return Theme.success
        }
        if entry.contains("<") {
            return Theme.accent
        }
        return Theme.textSecondary
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: Theme.paddingS) {
            // Quick action buttons
            HStack(spacing: Theme.paddingS) {
                actionButton("Connect", icon: "bolt.fill", color: Theme.success) {
                    gateway.connect()
                }

                actionButton("Ping", icon: "arrow.up.arrow.down", color: Theme.accent) {
                    gateway.sendPing()
                }

                actionButton("Status", icon: "info.circle", color: Theme.warning) {
                    gateway.requestStatus()
                }

                actionButton("Disconnect", icon: "xmark.circle", color: Theme.error) {
                    gateway.disconnect()
                    gateway.log("Disconnected by user")
                }
            }

            // Send test message
            HStack(spacing: Theme.paddingS) {
                TextField("Send test message...", text: $testMessage)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))

                Button {
                    guard !testMessage.isEmpty else { return }
                    gateway.sendMessage(testMessage)
                    gateway.log("> req:agent: \(testMessage)")
                    testMessage = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(testMessage.isEmpty ? Theme.textMuted : Theme.accent)
                }
                .disabled(testMessage.isEmpty)
            }

            // Bottom row: Clear log + Unpair
            HStack {
                Button {
                    gateway.connectionLog.removeAll()
                } label: {
                    Text("Clear Log")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                Button {
                    showUnpairConfirm = true
                } label: {
                    Label("Reset Pairing", systemImage: "arrow.uturn.backward")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.error)
                }
            }
        }
        .padding(Theme.paddingM)
        .background(Theme.surface)
        .confirmationDialog(
            "Reset pairing?",
            isPresented: $showUnpairConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset & enter new credentials", role: .destructive) {
                gateway.unpair()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disconnect, clear saved credentials, and return to the pairing screen.")
        }
    }

    private func actionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        }
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    let gw = GatewayService.shared
    NavigationStack {
        ConnectionTestView()
            .environmentObject(gw)
            .preferredColorScheme(.dark)
    }
}

#Preview("With logs") {
    let gw = GatewayService.shared
    let _ = {
        gw.log("Connecting to ws://192.168.1.42:18789...")
        gw.log("WebSocket opened, sending connect frame...")
        gw.log("Connect frame sent")
        gw.log("< {\"type\":\"welcome\",\"version\":\"0.9.2\",\"model\":\"claude-sonnet-4-20250514\"}")
        gw.log("Gateway confirmed connection")
        gw.log("> ping")
        gw.log("< {\"type\":\"pong\"}")
        gw.log("Pong received")
        gw.log("> req:status")
        gw.log("< {\"type\":\"event:status\",\"connected\":true}")
        gw.log("> req:agent: hello")
        gw.log("< {\"type\":\"event:agent\",\"content\":\"Hello! How can I help?\"}")
        gw.log("Connection error: The operation couldn't be completed.")
    }()
    NavigationStack {
        ConnectionTestView()
            .environmentObject(gw)
            .preferredColorScheme(.dark)
    }
}
