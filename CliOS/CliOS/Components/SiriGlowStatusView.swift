import SwiftUI

/// Connection status that drives the glow effect around the logo.
enum SiriGlowStatus {
    case idle
    case loading
    case connected
}

/// Logo with glow effects driven by connection status.
/// Single SiriGlowBorder masked by one unified arc that spins during loading
/// and expands to full circle on connected — no jumps.
struct SiriGlowStatusView: View {
    var status: SiriGlowStatus = .idle
    var cornerRadius: CGFloat = 28
    var logoSize: CGFloat = 120

    // Unified glow state
    @State private var glowVisible: Bool = false
    @State private var glowBlur: CGFloat = 2      // 2 for loader, 10 for connected
    @State private var arcFraction: CGFloat = 0.25 // how much of the circle is filled
    @State private var arcRotation: Double = 0     // current spin angle
    @State private var isSpinning: Bool = false

    // Bounce
    @State private var loaderScale: CGFloat = 1.0
    @State private var bounceScale: CGFloat = 1.0

    // Rays
    @State private var rayInner: CGFloat = 56
    @State private var rayOuter: CGFloat = 56
    @State private var rayIntensity: CGFloat = 0

    private let iconEdge: CGFloat = 56

    var body: some View {
        ZStack {
            // Rays layer
            SiriGlowRays(
                cornerRadius: cornerRadius,
                rayCount: 8,
                innerRadius: rayInner,
                outerRadius: rayOuter,
                intensity: rayIntensity,
                speed: 0
            )
            .frame(width: 300, height: 300)
            .allowsHitTesting(false)

            // Logo + single glow overlay
            Image("logoIconBlack")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(glowOverlay)
                .scaleEffect(bounceScale * loaderScale)
        }
        .frame(width: 300, height: 300)
        .onChange(of: status) { _, newStatus in
            switch newStatus {
            case .idle: transitionToIdle()
            case .loading: transitionToLoading()
            case .connected:
                // Small pause so loader spins a beat before celebrating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    transitionToConnected()
                }
            }
        }
    }

    // MARK: - Single glow overlay

    @ViewBuilder
    private var glowOverlay: some View {
        if glowVisible {
            SiriGlowBorder(
                cornerRadius: cornerRadius,
                lineWidth: 3,
                blurRadius: glowBlur,
                intensity: 1.0,
                speed: 1.0
            )
            .mask(
                PieMask(fraction: arcFraction)
                    .rotationEffect(.degrees(arcRotation))
                    .scaleEffect(2.5)
            )
        }
    }

    // MARK: - Transitions

    private func transitionToIdle() {
        isSpinning = false
        withAnimation(.easeOut(duration: 0.3)) {
            loaderScale = 1.0
            bounceScale = 1.0
            arcFraction = 0
            rayIntensity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            glowVisible = false
            arcFraction = 0.25
            arcRotation = 0
            glowBlur = 2
            rayInner = iconEdge
            rayOuter = iconEdge
        }
    }

    private func transitionToLoading() {
        // Reset
        isSpinning = false
        arcRotation = 0
        arcFraction = 0.25
        glowBlur = 2
        bounceScale = 1.0
        rayIntensity = 0
        rayInner = iconEdge
        rayOuter = iconEdge

        // Show and spin
        glowVisible = true
        loaderScale = 1.0

        // Start spin
        startSpin()

        // Loader breathe
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            loaderScale = 1.04
        }
    }

    private func startSpin() {
        isSpinning = true
        arcRotation = 0
        spinLoop()
    }

    private func spinLoop() {
        guard isSpinning else { return }
        withAnimation(.linear(duration: 1.2)) {
            arcRotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
            guard isSpinning else { return }
            spinLoop()
        }
    }

    private func transitionToConnected() {
        // 1. Stop spinning — freeze at current rotation
        isSpinning = false

        // 2. Stop breathe + bounce
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4, blendDuration: 0)) {
            loaderScale = 1.0
            bounceScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }

        // 3. Expand arc to full circle + increase blur — from current position, no jump
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.7)) {
                arcFraction = 1.0
                glowBlur = 10
            }
        }

        // 4. Rays burst — after bounce settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            rayInner = iconEdge
            rayOuter = iconEdge + 15
            rayIntensity = 1.0

            withAnimation(.easeOut(duration: 0.25)) {
                rayOuter = 110
                rayInner = 80
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    rayIntensity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                rayInner = iconEdge
                rayOuter = iconEdge
            }
        }
    }
}

// MARK: - Pie mask with soft edges

private struct PieMask: View, Animatable {
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    var body: some View {
        ZStack {
            PieShape(fraction: fraction)

            // Soft leading edge
            PieShape(fraction: min(fraction, 0.06))
                .blur(radius: 8)

            // Soft trailing edge
            if fraction < 0.98 {
                PieShape(fraction: fraction)
                    .mask(
                        PieShape(fraction: fraction)
                            .subtracting(PieShape(fraction: max(fraction - 0.06, 0)))
                    )
                    .blur(radius: 8)
            }
        }
    }
}

private struct PieShape: Shape {
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0.001 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height)

        if fraction >= 0.999 {
            // Full circle
            var p = Path()
            p.addEllipse(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            return p
        }

        let endAngle = Angle.degrees(Double(fraction) * 360 - 90)

        var p = Path()
        p.move(to: center)
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: endAngle,
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}
