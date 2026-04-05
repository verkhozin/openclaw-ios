import SwiftUI

struct PairingView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var manualHost = ""
    @State private var manualToken = ""
    @State private var showManual = false

    var body: some View {
        VStack(spacing: Theme.paddingL) {
            Spacer()

            if gateway.isVerifyingConnection {
                connectingContent
            } else {
                pairingContent
            }

            Spacer()

            // DEV: quick connect
            #if DEBUG
            if !gateway.isVerifyingConnection {
                Button {
                    gateway.pair(
                        url: URL(string: "ws://138.124.85.254:18789")!,
                        token: "0a7a1e581da351dd0ad93bf18b2fba1f40189d380abeb219"
                    )
                } label: {
                    Text("DEV Connect")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textMuted)
                        .padding(.bottom, Theme.paddingM)
                }
            }
            #endif
        }
        .background(Theme.bg)
    }

    // MARK: - Connecting state

    private var connectingContent: some View {
        VStack(spacing: Theme.paddingL) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.accent)

            Text("Connecting to Gateway...")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)

            Text("Verifying connection. This may take a few seconds.")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingL)
        }
    }

    // MARK: - Pairing input

    private var pairingContent: some View {
        VStack(spacing: Theme.paddingL) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(Theme.accent)

            Text("Connect to Gateway")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)

            Text("Scan QR code from your Gateway or enter connection details manually.")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingL)

            // Error message
            if let error = gateway.connectionError {
                Text(error)
                    .font(Theme.fontCaption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.paddingL)
            }

            // QR Scanner button
            Button {
                // TODO: Open camera for QR scan
                // QR contains: {"url": "ws://...", "token": "..."}
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .padding(.horizontal, Theme.paddingL)

            // Manual entry
            Button("Enter manually") {
                showManual.toggle()
            }
            .foregroundColor(Theme.textSecondary)

            if showManual {
                VStack(spacing: Theme.paddingS) {
                    TextField("Host (e.g. 192.168.1.100:18789)", text: $manualHost)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Gateway Token", text: $manualToken)
                        .textFieldStyle(.roundedBorder)

                    Button("Connect") {
                        guard let url = URL(string: "ws://\(manualHost)") else { return }
                        gateway.pair(url: url, token: manualToken)
                    }
                    .disabled(manualHost.isEmpty || manualToken.isEmpty)
                }
                .padding(.horizontal, Theme.paddingL)
            }
        }
    }
}
