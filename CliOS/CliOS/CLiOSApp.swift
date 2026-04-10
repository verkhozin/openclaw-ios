import SwiftUI

@main
struct CLiOSApp: App {
    @StateObject private var gateway = GatewayService.shared
    @State private var showMainAfterConnect = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showMainAfterConnect {
                    MainTabView()
                        .environmentObject(gateway)
                        .transition(.opacity.animation(.easeOut(duration: 0.6)))
                } else {
                    PairingView()
                        .environmentObject(gateway)
                        .transition(.opacity.animation(.easeOut(duration: 0.4)))
                }
            }
            .preferredColorScheme(.dark)
            .notificationOverlay(NotificationManager.shared)
            .onOpenURL { url in
                CLiOSApp.handleIncomingURL(url)
            }
            .onChange(of: gateway.isPaired) { _, paired in
                if paired && !gateway.isVerifyingConnection {
                    if showMainAfterConnect { return }
                    // Delay so user sees the "Connected" animation fully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            showMainAfterConnect = true
                        }
                    }
                } else if !paired {
                    showMainAfterConnect = false
                }
            }
            .onAppear {
                // Already paired from keychain — brief pause then animate in
                if gateway.isPaired {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showMainAfterConnect = true
                        }
                    }
                }
            }
        }
        .handlesExternalEvents(matching: ["*"])
        .commands { }
    }

    init() {
        // Handle URL scheme: clios://connect?host=X&port=Y&token=Z
    }
}

extension CLiOSApp {
    /// Parses `clios://connect?host=...&port=...&token=...` and calls pair()
    @MainActor
    static func handleIncomingURL(_ url: URL) {
        guard url.scheme == "clios",
              url.host == "connect",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return }

        let host = items.first(where: { $0.name == "host" })?.value
        let port = items.first(where: { $0.name == "port" })?.value
        let token = items.first(where: { $0.name == "token" })?.value

        guard let host, !host.isEmpty,
              let token, !token.isEmpty
        else { return }

        let portStr = port ?? "18789"
        guard let gatewayURL = URL(string: "ws://\(host):\(portStr)") else { return }

        GatewayService.shared.pair(url: gatewayURL, token: token)
    }
}
