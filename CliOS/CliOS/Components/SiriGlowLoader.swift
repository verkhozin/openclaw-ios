import SwiftUI

/// Loading state: rainbow gradient border masked to an arc that spins around the shape.
/// `arcFraction` controls how much of the border is visible (0.1 = thin tail, 0.5 = half).
struct SiriGlowLoader: View {
    var cornerRadius: CGFloat = 28
    var lineWidth: CGFloat = 3
    var blurRadius: CGFloat = 10
    var intensity: CGFloat = 1.0
    var speed: Double = 1.0
    var arcFraction: CGFloat = 0.3

    @State private var maskRotation: Double = 0

    private let colors: [Color] = [
        Color(hex: "FF6B6B"),
        Color(hex: "FF8E53"),
        Color(hex: "FFC857"),
        Color(hex: "6BCB77"),
        Color(hex: "4D96FF"),
        Color(hex: "9B59B6"),
        Color(hex: "FF6B9D"),
        Color(hex: "FF6B6B"),
    ]

    var body: some View {
        let clamped = max(0, min(1, intensity))

        ZStack {
            // Blurred outer layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(lineWidth: lineWidth + 2)
                .foregroundStyle(
                    AngularGradient(colors: colors, center: .center)
                )
                .blur(radius: blurRadius)
                .opacity(0.5 * clamped)
                .mask(arcMask)

            // Crisp inner layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(lineWidth: lineWidth)
                .foregroundStyle(
                    AngularGradient(colors: colors, center: .center)
                )
                .opacity(clamped)
                .mask(arcMask)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5 / speed)
                .repeatForever(autoreverses: false)
            ) {
                maskRotation = 360
            }
        }
        .allowsHitTesting(false)
    }

    /// Arc mask: angular gradient scaled up so it covers corners of the rounded rect.
    private var arcMask: some View {
        let solidEnd = arcFraction * 0.4
        let fadeEnd = arcFraction * 0.7
        let stops: [Gradient.Stop] = [
            .init(color: .white, location: 0),
            .init(color: .white, location: solidEnd),
            .init(color: .white.opacity(0.3), location: fadeEnd),
            .init(color: .clear, location: fadeEnd + 0.01),
            .init(color: .clear, location: 1.0),
        ]

        return AngularGradient(
            stops: stops,
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
        .scaleEffect(2.0)
        .rotationEffect(.degrees(maskRotation))
    }
}

// MARK: - View modifier

extension View {
    /// Adds a loading spinner glow border.
    func siriLoader(
        cornerRadius: CGFloat = 28,
        lineWidth: CGFloat = 3,
        blurRadius: CGFloat = 10,
        intensity: CGFloat = 1.0,
        speed: Double = 1.0,
        arcFraction: CGFloat = 0.3
    ) -> some View {
        self.overlay(
            SiriGlowLoader(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                blurRadius: blurRadius,
                intensity: intensity,
                speed: speed,
                arcFraction: arcFraction
            )
        )
    }
}
