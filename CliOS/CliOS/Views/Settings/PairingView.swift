import SwiftUI

struct PairingView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var manualHost = ""
    @State private var manualToken = ""
    @State private var showManual = false
    
    var body: some View {
        VStack(spacing: Theme.paddingL) {
            Spacer()
            
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
            
            Spacer()
        }
        .background(Theme.bg)
    }
}
