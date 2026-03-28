import SwiftUI

@main
struct CLiOSApp: App {
    @StateObject private var gateway = GatewayService.shared

    var body: some Scene {
        WindowGroup {
            if gateway.isPaired {
                MainTabView()
                    .environmentObject(gateway)
                    .preferredColorScheme(.dark)
            } else {
                PairingView()
                    .environmentObject(gateway)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
