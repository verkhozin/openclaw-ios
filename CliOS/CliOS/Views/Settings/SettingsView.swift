import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gateway: GatewayService
    
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
        }
    }
}
