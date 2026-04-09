import SwiftUI

// MARK: - Gateway Connection State

enum GatewayConnectionState: CaseIterable, Identifiable {
    case connected, reconnecting

    var id: Self { self }

    var label: String {
        switch self {
        case .connected: return "GATEWAY LINK ESTABLISHED"
        case .reconnecting: return "CONNECTING TO GATEWAY\u{2026}"
        }
    }

    var color: Color {
        switch self {
        case .connected: return Color(hex: "00FF87")
        case .reconnecting: return Color(hex: "FFB800")
        }
    }
}



// MARK: - Signal Field Radar View

/// Radar-style signal field visualization.
/// Concentric arcs radiate from the bottom-center (the "source"),
/// expanding upward like a radar/sonar. Target sits near the top.
struct SignalFieldRadarView: View {
    let state: GatewayConnectionState
    var latencyMs: Int = 47

    // Pulse animation
    @State private var pulseScale: CGFloat = 0
    @State private var pulseOpacity: CGFloat = 0
    // Color transition — animated, Canvas reads this
    @State private var colorBlend: CGFloat = 0 // 0 = amber, 1 = green

    @State private var spinAngle: Double = 0

    // Blended color for SwiftUI layers
    private var blendedColor: Color {
        let t = Double(colorBlend)
        // Amber FFB800: (1.0, 0.722, 0.0) → Green 00FF87: (0.0, 1.0, 0.529)
        return Color(
            .sRGB,
            red: 1.0 + (0.0 - 1.0) * t,
            green: 0.722 + (1.0 - 0.722) * t,
            blue: 0.0 + (0.529 - 0.0) * t,
            opacity: 1
        )
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let targetY: CGFloat = size.height * 0.18
            let centerX: CGFloat = size.width * 0.5

            ZStack {
                // Layer 1: Canvas — radar arcs, contours, target
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, sz in
                        let origin = CGPoint(x: sz.width * 0.5, y: sz.height + 10)
                        let tgtX = sz.width * 0.50
                        let tgtY = sz.height * 0.18

                        let blend = Double(colorBlend)
                        let r = 1.0 + (0.0 - 1.0) * blend
                        let g = 0.722 + (1.0 - 0.722) * blend
                        let b = 0.0 + (0.529 - 0.0) * blend
                        let color = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
                        let baseAlpha: CGFloat = CGFloat(0.40 + (0.28 - 0.40) * blend)
                        let strokeW: CGFloat = CGFloat(0.8 + (0.7 - 0.8) * blend)

                        drawContourRings(in: ctx, size: sz, time: t, origin: origin, color: color)
                        drawRadarArcs(in: ctx, size: sz, time: t, origin: origin, color: color,
                                      baseAlpha: baseAlpha, strokeW: strokeW)
                        drawTarget(in: ctx, size: sz, time: t, targetX: tgtX, targetY: tgtY, color: color)
                    }
                }

                // Layer 2: Pulse
                Circle()
                    .fill(Color(hex: "00FF87").opacity(pulseOpacity * 0.12))
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseScale)
                    .position(x: centerX, y: targetY)

                // Layer 3: Top fade to black
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black.opacity(0.5), location: 0.5),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 28)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Layer 4: Text overlay
                VStack {
                    Spacer()
                    HStack(alignment: .lastTextBaseline) {
                        Text(state.label)
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(blendedColor.opacity(0.85))
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.4), value: state)

                        Spacer()

                        if state == .connected {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(latencyMs)")
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .contentTransition(.numericText())
                                Text("ms")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .contentTransition(.numericText())
                            }
                        } else {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(blendedColor.opacity(0.45))
                                .rotationEffect(.degrees(spinAngle))
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: state)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            if state == .connected {
                colorBlend = 1
            } else {
                colorBlend = 0
                startSpinner()
            }
        }
        .onChange(of: state) { oldVal, newVal in
            if newVal == .connected && oldVal == .reconnecting {
                triggerConnect()
            } else if newVal == .reconnecting {
                resetToReconnecting()
            }
        }
    }

    // MARK: - Transitions

    private func triggerConnect() {
        // Smooth color blend over 1s
        withAnimation(.easeInOut(duration: 1.0)) {
            colorBlend = 1
        }

        // Pulse from target
        pulseScale = 0.05
        pulseOpacity = 0
        withAnimation(.easeOut(duration: 0.6)) {
            pulseScale = 1.0
            pulseOpacity = 0.5
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) {
                    pulseOpacity = 0
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                pulseScale = 0
            }
        }
    }

    private func resetToReconnecting() {
        pulseScale = 0
        pulseOpacity = 0
        withAnimation(.easeInOut(duration: 0.8)) {
            colorBlend = 0
        }
        startSpinner()
    }

    private func startSpinner() {
        spinAngle = 0
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            spinAngle = 360
        }
    }

    // MARK: - Canvas drawing

    private func drawContourRings(in ctx: GraphicsContext, size: CGSize, time: Double,
                                   origin: CGPoint, color: Color) {
        let ringCount = 7
        let maxR: CGFloat = size.height * 1.6
        let breathe = sin(time * 0.35) * 1.0

        for i in 0..<ringCount {
            let t = CGFloat(i + 1) / CGFloat(ringCount + 1)
            let r = maxR * t + breathe * CGFloat(i)
            let alpha: CGFloat = i < 2 ? 0.035 : 0.022

            var path = Path()
            path.addEllipse(in: CGRect(
                x: origin.x - r, y: origin.y - r,
                width: r * 2, height: r * 2
            ))
            ctx.stroke(path, with: .color(color.opacity(alpha)), lineWidth: 0.4)
        }
    }

    private func drawRadarArcs(in ctx: GraphicsContext, size: CGSize, time: Double,
                                origin: CGPoint, color: Color,
                                baseAlpha: CGFloat, strokeW: CGFloat) {
        let spacing: CGFloat = 35
        let maxR: CGFloat = size.height * 1.5
        let numArcs = Int(ceil(maxR / spacing)) + 1
        let phase = CGFloat(time) * 35
        let offset = phase.truncatingRemainder(dividingBy: spacing)

        for i in 0..<numArcs {
            let r = CGFloat(i) * spacing + offset
            guard r > 5, r < maxR else { continue }

            let progress = r / maxR
            let edgeFade: CGFloat = progress > 0.85
                ? max(0, (1.0 - progress) / 0.15) : 1.0
            let positionFade = 1.0 - progress * 0.4
            let alpha = baseAlpha * edgeFade * positionFade

            var path = Path()
            path.addEllipse(in: CGRect(
                x: origin.x - r, y: origin.y - r,
                width: r * 2, height: r * 2
            ))
            ctx.stroke(path, with: .color(color.opacity(alpha)), lineWidth: strokeW)
        }
    }

    private func drawTarget(in ctx: GraphicsContext, size: CGSize, time: Double,
                             targetX: CGFloat, targetY: CGFloat, color: Color) {
        guard state == .connected else { return }
        // Glow
        let g: CGFloat = 16
        ctx.fill(
            Circle().path(in: CGRect(x: targetX - g, y: targetY - g, width: g * 2, height: g * 2)),
            with: .color(color.opacity(0.08))
        )
        // Dot
        let r: CGFloat = 4
        ctx.fill(
            Circle().path(in: CGRect(x: targetX - r, y: targetY - r, width: r * 2, height: r * 2)),
            with: .color(color)
        )
    }
}
