import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var showImmersiveTest = false
    @State private var showClearSessionsConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Gateway") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(gateway.status.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(gateway.status.isConnected ? Theme.success : Theme.error)
                    }

                    HStack {
                        Text("Model")
                        Spacer()
                        Text(gateway.status.model)
                            .foregroundColor(Theme.textSecondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(gateway.status.version)
                            .foregroundColor(Theme.textSecondary)
                    }

                    NavigationLink {
                        ConnectionTestView()
                            .environmentObject(gateway)
                    } label: {
                        Label("Connection Test", systemImage: "waveform.path.ecg")
                            .foregroundColor(Theme.accent)
                    }
                }
                
                Section("Services") {
                    // TODO: Toggle per service (GitHub, Email, Calendar, etc.)
                    Text("No services configured")
                        .foregroundColor(Theme.textMuted)
                }
                
                Section("Privacy") {
                    // TODO: Data access toggles
                    // TODO: Action log
                    // TODO: Guardrails
                    Text("Privacy controls")
                        .foregroundColor(Theme.textMuted)
                }
                
                Section("Dynamic Island Test") {
                    Button {
                        showImmersiveTest = true
                    } label: {
                        Label("Enter Immersive Mode", systemImage: "rectangle.inset.filled")
                            .foregroundColor(Theme.accent)
                    }

                    Text("Opens a fullscreen immersive screen that suppresses Dynamic Island Live Activities (timers, music, etc.). Swipe down to exit.")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                }

                Section("Developer") {
                    NavigationLink {
                        CardCatalogView()
                    } label: {
                        Label("Card Catalog", systemImage: "rectangle.grid.1x2")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        ShaderPlaygroundView()
                    } label: {
                        Label("Shader Playground", systemImage: "sparkles")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        ChatScreenView()
                            .navigationBarHidden(true)
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Chat Screen", systemImage: "bubble.left.fill")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        FileExplorerView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("File Explorer", systemImage: "folder.badge.gearshape")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        TaskTrackerView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Task Tracker", systemImage: "checklist")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        SiriGlowGalleryView()
                    } label: {
                        Label("Siri Glow", systemImage: "rainbow")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        PairingMockView()
                            .navigationBarHidden(true)
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Pairing Flow", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        NotificationMockView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        GatewayStatusMockView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Gateway Signal Field", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        IslandCalibrationView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Island Calibration", systemImage: "island")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        PillTabBarMockView()
                            .navigationBarHidden(true)
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Pill Tab Bar", systemImage: "capsule.fill")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        ChatCardsMockView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Chat Cards", systemImage: "rectangle.stack")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        DashboardMockView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Dashboard v2", systemImage: "squares.leading.rectangle")
                            .foregroundColor(Theme.accent)
                    }

                    NavigationLink {
                        ProjectsMockView()
                            .toolbar(.hidden, for: .tabBar)
                    } label: {
                        Label("Projects", systemImage: "folder.fill")
                            .foregroundColor(Theme.accent)
                    }
                }

                Section("Demo") {
                    Button("Clear All Sessions", role: .destructive) {
                        showClearSessionsConfirm = true
                    }
                }

                Section {
                    Button("Disconnect Gateway", role: .destructive) {
                        gateway.unpair()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showImmersiveTest) {
                ImmersiveTestScreen()
            }
            .confirmationDialog("Clear all sessions?", isPresented: $showClearSessionsConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    gateway.sessionStore.clearSessionsForDemo()
                }
            } message: {
                Text("Sessions will disappear until app restart.")
            }
        }
    }
}

// MARK: - Immersive Test Screen

/// Fullscreen test screen presented via ImmersiveHostingController.
/// All DI suppression overrides come from the hosting controller.
private struct ImmersiveTestScreen: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> ImmersiveHostingController {
        return ImmersiveHostingController(rootView: AnyView(ImmersiveTestContent()))
    }

    func updateUIViewController(_ uiViewController: ImmersiveHostingController, context: Context) {}
}

private struct ImmersiveTestContent: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)

                Text("Immersive Mode")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("Dynamic Island Live Activities\nshould be hidden now.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    checkRow("prefersStatusBarHidden = true")
                    checkRow("prefersHomeIndicatorAutoHidden = true")
                    checkRow("preferredScreenEdgesDeferring = [.top, .bottom]")
                    checkRow("isIdleTimerDisabled = true")
                }
                .padding(.top, 16)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Exit Immersive Mode")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.white, in: Capsule())
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }

    private func checkRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.success)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
