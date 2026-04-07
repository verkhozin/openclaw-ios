import SwiftUI

/// Animated rainbow glow border inspired by Apple's Siri UI.
/// `intensity` controls visibility (0 = invisible, 1 = full glow).
struct SiriGlowBorder: View {
    var cornerRadius: CGFloat = 28
    var lineWidth: CGFloat = 3
    var blurRadius: CGFloat = 12
    var intensity: CGFloat = 1.0
    var speed: Double = 1.0

    @State private var rotation: Double = 0

    private let colors: [Color] = [
        Color(hex: "FF6B6B"), // red-pink
        Color(hex: "FF8E53"), // orange
        Color(hex: "FFC857"), // yellow
        Color(hex: "6BCB77"), // green
        Color(hex: "4D96FF"), // blue
        Color(hex: "9B59B6"), // purple
        Color(hex: "FF6B9D"), // magenta
        Color(hex: "FF6B6B"), // wrap back to red
    ]

    var body: some View {
        let clampedIntensity = max(0, min(1, intensity))

        ZStack {
            // Outer glow (blurred, wider)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(lineWidth: lineWidth + 2)
                .foregroundStyle(
                    AngularGradient(
                        colors: colors,
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
                .blur(radius: blurRadius)
                .opacity(0.6 * clampedIntensity)

            // Inner crisp border
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(lineWidth: lineWidth)
                .foregroundStyle(
                    AngularGradient(
                        colors: colors,
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
                .opacity(clampedIntensity)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 4.0 / speed)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - View modifier for convenience

extension View {
    /// Adds animated rainbow glow border.
    func siriGlow(
        cornerRadius: CGFloat = 28,
        lineWidth: CGFloat = 3,
        blurRadius: CGFloat = 12,
        intensity: CGFloat = 1.0,
        speed: Double = 1.0
    ) -> some View {
        self.overlay(
            SiriGlowBorder(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                blurRadius: blurRadius,
                intensity: intensity,
                speed: speed
            )
        )
    }
}
