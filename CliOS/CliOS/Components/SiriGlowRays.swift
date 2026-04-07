import SwiftUI

/// A single tapered ray shape. Both inner and outer radius are animatable
/// so the ray can "fly out" — tail detaches from the icon.
struct RayShape: Shape {
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var baseWidth: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(innerRadius, outerRadius) }
        set {
            innerRadius = newValue.first
            outerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startY = center.y - innerRadius
        let endY = center.y - outerRadius
        let halfBase = baseWidth / 2
        let halfTip = baseWidth * 0.15

        var p = Path()
        p.move(to: CGPoint(x: center.x - halfBase, y: startY))
        p.addLine(to: CGPoint(x: center.x - halfTip, y: endY))
        p.addLine(to: CGPoint(x: center.x + halfTip, y: endY))
        p.addLine(to: CGPoint(x: center.x + halfBase, y: startY))
        p.closeSubpath()
        return p
    }
}

/// Animated rainbow rays radiating outward from a rounded rectangle.
struct SiriGlowRays: View {
    var cornerRadius: CGFloat = 28
    var rayCount: Int = 14
    var innerRadius: CGFloat? = nil   // defaults to shape edge
    var outerRadius: CGFloat? = nil   // defaults to innerRadius + rayLength
    var rayLength: CGFloat = 40       // used when outerRadius is nil
    var intensity: CGFloat = 1.0
    var speed: Double = 1.0

    @State private var baseRotation: Double = 0

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

        GeometryReader { geo in
            let size = geo.size
            let shapeRadius = min(size.width, size.height) / 2
            let inner = innerRadius ?? (shapeRadius - 4)
            let outer = outerRadius ?? (inner + rayLength)

            ZStack {
                ForEach(0..<rayCount, id: \.self) { i in
                    let angle = Double(i) / Double(rayCount) * 360.0
                    let color = colorForIndex(i)

                    // Blurred wide layer
                    RayShape(innerRadius: inner, outerRadius: outer * 1.3, baseWidth: 16)
                        .fill(color)
                        .blur(radius: 16)
                        .opacity(0.35 * clamped)
                        .rotationEffect(.degrees(angle + baseRotation))

                    // Sharp layer
                    RayShape(innerRadius: inner, outerRadius: outer, baseWidth: 5)
                        .fill(color)
                        .blur(radius: 3)
                        .opacity(0.7 * clamped)
                        .rotationEffect(.degrees(angle + baseRotation))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear {
            guard speed > 0 else { return }
            withAnimation(
                .linear(duration: 6.0 / speed)
                .repeatForever(autoreverses: false)
            ) {
                baseRotation = 360
            }
        }
        .allowsHitTesting(false)
    }

    private func colorForIndex(_ i: Int) -> Color {
        let t = Double(i) / Double(rayCount) * Double(colors.count - 1)
        let lo = Int(t) % colors.count
        let hi = (lo + 1) % colors.count
        let frac = t - Double(lo)
        let a = UIColor(colors[lo]), b = UIColor(colors[hi])
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar) + Double(br - ar) * frac,
            green: Double(ag) + Double(bg - ag) * frac,
            blue: Double(ab) + Double(bb - ab) * frac
        )
    }
}

// MARK: - View modifier

extension View {
    /// Adds animated rainbow rays radiating outward.
    func siriRays(
        cornerRadius: CGFloat = 28,
        rayCount: Int = 14,
        rayLength: CGFloat = 40,
        intensity: CGFloat = 1.0,
        speed: Double = 1.0
    ) -> some View {
        self.overlay(
            SiriGlowRays(
                cornerRadius: cornerRadius,
                rayCount: rayCount,
                rayLength: rayLength,
                intensity: intensity,
                speed: speed
            )
            .frame(width: 300, height: 300)
            .allowsHitTesting(false)
        )
    }
}
