import SwiftUI

/// Real pairing screen — full flow:
/// welcome → continue → copy prompt → waiting for deep link → connected → auto-transition to app
struct PairingView: View {
    @EnvironmentObject var gateway: GatewayService

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
    @State private var copied = false
    @State private var waitingForLink = false
    @State private var recopied = false
    @State private var shaderVisible = true

    // Intro animation
    @State private var logoVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var buttonVisible = false

    /// Maps gateway state to glow status
    private var glowStatus: SiriGlowStatus {
        if gateway.isVerifyingConnection { return .loading }
        if gateway.status.isConnected { return .connected }
        if waitingForLink { return .loading }
        return .idle
    }

    var body: some View {
        ZStack {
            // Black base
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

                // Logo
                SiriGlowStatusView(status: glowStatus, cornerRadius: 32, logoSize: 150)
                    .frame(height: 180)
                    .scaleEffect(logoVisible ? 1 : 0.8)
                    .opacity(logoVisible ? 1 : 0)

                // Text area
                ZStack {
                    // Welcome text
                    VStack(spacing: 6) {
                        Text("CLiOS")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(Self.textWhite)
                            .opacity(titleVisible ? welcomeTextOpacity : 0)
                            .offset(y: step == .welcome ? 0 : -10)
                            .animation(.easeOut(duration: 0.3), value: step)

                        Text("Your OpenClaw agent, one tap away")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Self.textGray)
                            .opacity(subtitleVisible ? welcomeTextOpacity : 0)
                            .offset(y: step == .welcome ? 0 : -10)
                            .animation(.easeOut(duration: 0.3).delay(0.06), value: step)
                    }

                    // Setup text
                    setupText
                        .opacity(setupTextOpacity)
                        .animation(.easeOut(duration: 0.35).delay(step == .setup ? 0.2 : 0), value: step)
                        .animation(.easeInOut(duration: 0.35), value: glowStatus)
                }
                .frame(height: 120, alignment: .center)
                .padding(.top, 16)

                // Error
                if let error = gateway.connectionError {
                    Text(error)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                Spacer()

                // Bottom button
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
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startIntroAnimation() }
        .onChange(of: gateway.isVerifyingConnection) { _, verifying in
            // Deep link arrived → auto-switch to setup step
            if verifying && step == .welcome {
                withAnimation(.easeInOut(duration: 0.5)) {
                    step = .setup
                }
            }
        }
        .onChange(of: gateway.isPaired) { _, paired in
            if paired {
                // Stop shader to save GPU before transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    shaderVisible = false
                }
            }
        }
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
        if gateway.isVerifyingConnection { return "Connecting..." }
        if gateway.status.isConnected { return "Connected" }
        if waitingForLink { return "Waiting for agent..." }
        return "Connect to your agent"
    }

    private var setupSubtitle: String {
        if gateway.isVerifyingConnection { return "Establishing connection to Gateway..." }
        if gateway.status.isConnected { return "You're all set!" }
        if waitingForLink { return "Paste the copied prompt to your AI agent.\nIt will send you a connection link." }
        return "Copy the setup prompt and send it to your AI agent.\nIt will send you a connection link."
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
        .animation(.easeInOut(duration: 0.35), value: gateway.isVerifyingConnection)
        .animation(.easeInOut(duration: 0.35), value: gateway.status.isConnected)
        .animation(.easeInOut(duration: 0.35), value: waitingForLink)
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
        if gateway.isVerifyingConnection {
            EmptyView()
        } else if gateway.status.isConnected {
            EmptyView()
        } else if waitingForLink {
            Button {
                UIPasteboard.general.string = Self.setupPrompt
                recopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        recopied = false
                    }
                }
            } label: {
                Label(
                    recopied ? "Copied!" : "Copy prompt again",
                    systemImage: recopied ? "checkmark" : "doc.on.doc"
                )
                .font(.system(.subheadline, design: .default))
                .foregroundColor(recopied ? Self.textWhite : Self.textDimGray)
                .animation(.easeInOut(duration: 0.2), value: recopied)
            }
        } else {
            Button {
                copyPrompt()
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

    // MARK: - Actions

    private func copyPrompt() {
        UIPasteboard.general.string = Self.setupPrompt
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                waitingForLink = true
                copied = false
            }
        }
    }

    // MARK: - Intro animation

    private func startIntroAnimation() {
        // Logo scales in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
            logoVisible = true
        }
        // Title fades up
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            titleVisible = true
        }
        // Subtitle fades up
        withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
            subtitleVisible = true
        }
        // Button slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
            buttonVisible = true
        }
    }
}

#Preview {
    PairingView()
        .environmentObject(GatewayService.shared)
}
