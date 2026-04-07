import SwiftUI

/// Mock pairing screen — full flow:
/// welcome → continue → copy prompt → loading → connected
struct PairingMockView: View {
    enum Step {
        case welcome
        case setup
    }

    // MARK: - Hardcoded dark colors (theme-independent)
    private static let bgColor = Color.black
    private static let surfaceColor = Color(white: 0.10)
    private static let textWhite = Color.white
    private static let textGray = Color(white: 0.65)
    private static let textDimGray = Color(white: 0.45)

    @State private var step: Step = .welcome
    @State private var status: SiriGlowStatus = .idle
    @State private var copied = false
    @State private var shaderVisible = true

    var body: some View {
        ZStack {
            // Black base to prevent any system bg leaking
            Self.bgColor.ignoresSafeArea()

            // Dark plasma background
            MetalShaderView(
                fps: 60,
                shader: .plasma,
                tintColor: SIMD3<Float>(0.30, 0.03, 0.0),
                timeScale: 0.35,
                isVisible: $shaderVisible
            )
            .ignoresSafeArea()
            .saturation(0)
            .brightness(-0.15)
            .blur(radius: 10)

            Rectangle()
                .fill(Color.black)
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 200)

                // Logo — pinned position
                SiriGlowStatusView(status: status, cornerRadius: 32, logoSize: 150)
                    .frame(height: 180)

                // Text area — fixed height, ZStack for crossfade
                ZStack {
                    // Welcome text — line by line staggered
                    VStack(spacing: 6) {
                        Text("CLiOS")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(Self.textWhite)
                            .opacity(welcomeTextOpacity)
                            .offset(y: step == .welcome ? 0 : -10)
                            .animation(.easeOut(duration: 0.3), value: step)

                        Text("Your OpenClaw agent, one tap away")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Self.textGray)
                            .opacity(welcomeTextOpacity)
                            .offset(y: step == .welcome ? 0 : -10)
                            .animation(.easeOut(duration: 0.3).delay(0.06), value: step)
                    }

                    // Setup text — title first, then description
                    setupText
                        .opacity(setupTextOpacity)
                        .animation(.easeOut(duration: 0.35).delay(step == .setup ? 0.2 : 0), value: step)
                        .animation(.easeInOut(duration: 0.35), value: status)
                }
                .frame(height: 120, alignment: .center)
                .padding(.top, 16)

                Spacer()

                // Bottom button — fixed height container
                Group {
                    switch step {
                    case .welcome:
                        continueButton
                    case .setup:
                        setupButton
                    }
                }
                .frame(height: 56)
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Text opacity

    private var welcomeTextOpacity: Double {
        step == .welcome ? 1 : 0
    }

    private var setupTextOpacity: Double {
        step == .setup ? 1 : 0
    }

    // MARK: - Setup text

    private var setupTitle: String {
        switch status {
        case .idle: return "Connect to your agent"
        case .loading: return "Connecting..."
        case .connected: return "Connected"
        }
    }

    private var setupSubtitle: String {
        switch status {
        case .idle: return "Copy the setup prompt and send it to your AI agent.\nIt will send you a connection link."
        case .loading: return "Waiting for connection link from your agent..."
        case .connected: return "You're all set!"
        }
    }

    private var setupText: some View {
        VStack(spacing: 8) {
            Text(setupTitle)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundColor(Self.textWhite)
                .offset(y: step == .setup ? 0 : 10)
                .animation(.easeOut(duration: 0.3), value: step)

            Text(setupSubtitle)
                .font(.system(.body, design: .default))
                .foregroundColor(Self.textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .offset(y: step == .setup ? 0 : 10)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: step)
        }
        .animation(.easeInOut(duration: 0.35), value: status)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.5)) {
                step = .setup
            }
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Setup button

    @ViewBuilder
    private var setupButton: some View {
        switch status {
        case .idle:
            Button {
                simulateCopy()
            } label: {
                Label(
                    copied ? "Copied!" : "Copy Setup Prompt",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Self.surfaceColor)
                .foregroundColor(Self.textWhite)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .siriGlow(
                    cornerRadius: 20,
                    lineWidth: 1.5,
                    blurRadius: 4,
                    intensity: copied ? 0 : 1.0,
                    speed: 0.5
                )
            }

        case .loading:
            Button {
                simulateConnect()
            } label: {
                Text("Simulate Deep Link")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(Self.textDimGray)
            }

        case .connected:
            Button {
                reset()
            } label: {
                Text("Reset Demo")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(Self.textDimGray)
            }
        }
    }

    // MARK: - Setup prompt

    private static let setupPrompt = """
    Connect my CLiOS app to the Gateway:

    1. Set gateway.bind to "0.0.0.0" in Gateway config and restart the gateway
    2. Send me the connection link via GitHub Pages redirect (plain clickable text, not in a code block): https://verkh-agents.github.io/clios/connect.html?host=YOUR_IP&port=18789&token=YOUR_TOKEN
    3. Poll device.pair.list every 5 seconds (up to 2 minutes) until a pending request with platform "ios" appears, then immediately run device.pair.approve with its requestId
    4. In the background, install CLiOS skill: git clone https://github.com/verkh-agents/clios.git /tmp/clios && cp -r /tmp/clios/skills/clios ~/.openclaw/workspace/skills/ && rm -rf /tmp/clios
    5. Reply with only: "Connected ✓"
    """

    // MARK: - Simulation

    private func simulateCopy() {
        UIPasteboard.general.string = Self.setupPrompt
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                status = .loading
                copied = false
            }
        }
    }

    private func simulateConnect() {
        withAnimation(.easeInOut(duration: 0.4)) {
            status = .connected
        }
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.4)) {
            status = .idle
            step = .welcome
        }
    }
}

#Preview {
    PairingMockView()
}
