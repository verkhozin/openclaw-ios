import SwiftUI

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case home, workspace, command, chat, agent

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .workspace: return "rectangle.grid.2x2.fill"
        case .command: return "bolt.fill"
        case .chat: return "bubble.left.fill"
        case .agent: return "cpu.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .workspace: return "Workspace"
        case .command: return "Command"
        case .chat: return "Chat"
        case .agent: return "Agent"
        }
    }

    var isCenter: Bool { self == .command }
    static var leftTabs: [AppTab] { [.home, .workspace] }
    static var rightTabs: [AppTab] { [.chat, .agent] }
}

// MARK: - Metaball Tab Bar Shape
//
// Two pills (left, right) connected to a center circle via smooth organic necks.
// The neck curves use cubic beziers with tangent-matched control points
// so the transition from neck to circle arc is perfectly smooth (C1 continuous).
//
// Key parameters:
//   centerRadius    — radius of the center circle
//   gapWidth        — horizontal distance between pill inner edge and circle outer edge
//   connectionAngle — degrees from horizontal (180°/0°) where the neck meets the circle.
//                     30° means the neck connects at 210° and 150° (left side).
//                     Larger = more circle visible, narrower neck entrance.
//   neckTension     — 0...1, controls bezier handle length (how tight the neck curves are)

struct MetaballTabBarShape: Shape {
    var centerRadius: CGFloat = 28
    var gapWidth: CGFloat = 14
    var connectionAngle: CGFloat = 30
    var neckTension: CGFloat = 0.7

    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let midY = rect.midY
        let pillR = rect.height / 2
        let cr = centerRadius
        let ca = connectionAngle * .pi / 180
        let cosCA = cos(ca)
        let sinCA = sin(ca)

        // Pill inner edges (where the flat top/bottom ends and the neck begins)
        let neckL = midX - cr - gapWidth
        let neckR = midX + cr + gapWidth

        // Connection points on the circle (screen coords, y-down)
        // Left upper (angle 180°+ca = 210° for ca=30°)
        let luPt = CGPoint(x: midX - cr * cosCA, y: midY - cr * sinCA)
        // Left lower (angle 180°-ca = 150°)
        let llPt = CGPoint(x: midX - cr * cosCA, y: midY + cr * sinCA)
        // Right upper (angle 360°-ca = 330°)
        let ruPt = CGPoint(x: midX + cr * cosCA, y: midY - cr * sinCA)
        // Right lower (angle ca = 30°)
        let rlPt = CGPoint(x: midX + cr * cosCA, y: midY + cr * sinCA)

        // Bezier handle length
        let k = gapWidth * neckTension

        // Tangent directions at connection points (screen-CW = increasing angle direction).
        // Formula: tangent at angle θ = (-sinθ, cosθ) — derivative of (cosθ, sinθ).
        // At 180°+ca: tangent = ( sinCA, -cosCA) — going right-up
        // At 360°-ca: tangent = ( sinCA,  cosCA) — going right-down
        // At       ca: tangent = (-sinCA,  cosCA) — going left-down
        // At 180°-ca: tangent = (-sinCA, -cosCA) — going left-up

        var p = Path()

        // ── Start: top of left pill outer cap ──
        p.move(to: CGPoint(x: rect.minX + pillR, y: rect.minY))

        // ── Top edge of left pill ──
        p.addLine(to: CGPoint(x: neckL, y: rect.minY))

        // ── Left neck TOP ──
        // From pill top → circle at 210°
        // Start tangent: (1, 0) = horizontal right
        // End tangent: (sinCA, -cosCA) = right-up (matching arc start at 210°)
        p.addCurve(
            to: luPt,
            control1: CGPoint(x: neckL + k, y: rect.minY),
            control2: CGPoint(x: luPt.x - sinCA * k, y: luPt.y + cosCA * k)
        )

        // ── Circle TOP arc ──
        // From 210° to 330° going screen-CW (through 270° = top)
        // clockwise:false = increasing angles = screen-CW
        p.addArc(
            center: CGPoint(x: midX, y: midY), radius: cr,
            startAngle: .degrees(180 + Double(connectionAngle)),
            endAngle: .degrees(360 - Double(connectionAngle)),
            clockwise: false
        )

        // ── Right neck TOP ──
        // From circle at 330° → pill top
        // Start tangent: (sinCA, cosCA) = right-down (matching arc end at 330°)
        // End tangent: (1, 0) = horizontal right
        p.addCurve(
            to: CGPoint(x: neckR, y: rect.minY),
            control1: CGPoint(x: ruPt.x + sinCA * k, y: ruPt.y + cosCA * k),
            control2: CGPoint(x: neckR - k, y: rect.minY)
        )

        // ── Top edge of right pill ──
        p.addLine(to: CGPoint(x: rect.maxX - pillR, y: rect.minY))

        // ── Right pill cap ──
        // From 270° (top) through 0° (right) to 90° (bottom)
        p.addArc(
            center: CGPoint(x: rect.maxX - pillR, y: midY), radius: pillR,
            startAngle: .degrees(270), endAngle: .degrees(90),
            clockwise: false
        )

        // ── Bottom edge of right pill ──
        p.addLine(to: CGPoint(x: neckR, y: rect.maxY))

        // ── Right neck BOTTOM ──
        // From pill bottom → circle at 30°
        // Start tangent: (-1, 0) = horizontal left
        // End tangent: (-sinCA, cosCA) = left-down (matching arc start at 30°)
        p.addCurve(
            to: rlPt,
            control1: CGPoint(x: neckR - k, y: rect.maxY),
            control2: CGPoint(x: rlPt.x + sinCA * k, y: rlPt.y - cosCA * k)
        )

        // ── Circle BOTTOM arc ──
        // From 30° to 150° going screen-CW (through 90° = bottom)
        p.addArc(
            center: CGPoint(x: midX, y: midY), radius: cr,
            startAngle: .degrees(Double(connectionAngle)),
            endAngle: .degrees(180 - Double(connectionAngle)),
            clockwise: false
        )

        // ── Left neck BOTTOM ──
        // From circle at 150° → pill bottom
        // Start tangent: (-sinCA, -cosCA) = left-up (matching arc end at 150°)
        // End tangent: (-1, 0) = horizontal left
        p.addCurve(
            to: CGPoint(x: neckL, y: rect.maxY),
            control1: CGPoint(x: llPt.x - sinCA * k, y: llPt.y - cosCA * k),
            control2: CGPoint(x: neckL + k, y: rect.maxY)
        )

        // ── Bottom edge of left pill ──
        p.addLine(to: CGPoint(x: rect.minX + pillR, y: rect.maxY))

        // ── Left pill cap ──
        // From 90° (bottom) through 180° (left) to 270° (top)
        p.addArc(
            center: CGPoint(x: rect.minX + pillR, y: midY), radius: pillR,
            startAngle: .degrees(90), endAngle: .degrees(270),
            clockwise: false
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - E1: Metaball (neutral center)

struct TabBarMetaball: View {
    @Binding var selected: AppTab
    var onCommand: () -> Void

    private let barHeight: CGFloat = 56
    private let centerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            MetaballTabBarShape(centerRadius: centerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    MetaballTabBarShape(centerRadius: centerRadius)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .frame(height: barHeight)

            tabContent
        }
    }

    private var tabContent: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.leftTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }

            Button(action: onCommand) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: centerRadius * 2 + 28, height: barHeight)
            }

            ForEach(AppTab.rightTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .frame(height: barHeight)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selected == tab ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - E2: Metaball + Glow

struct TabBarMetaballGlow: View {
    @Binding var selected: AppTab
    var onCommand: () -> Void

    private let barHeight: CGFloat = 56
    private let centerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            MetaballTabBarShape(centerRadius: centerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    MetaballTabBarShape(centerRadius: centerRadius)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .frame(height: barHeight)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.35), .clear],
                        center: .center, startRadius: 4, endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .blur(radius: 6)

            tabContent
        }
    }

    private var tabContent: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.leftTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }

            Button(action: onCommand) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accent.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: centerRadius * 2 + 28, height: barHeight)
            }

            ForEach(AppTab.rightTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .frame(height: barHeight)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selected == tab ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - E3: Metaball + Filled

struct TabBarMetaballFilled: View {
    @Binding var selected: AppTab
    var onCommand: () -> Void

    private let barHeight: CGFloat = 56
    private let centerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            MetaballTabBarShape(centerRadius: centerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    MetaballTabBarShape(centerRadius: centerRadius)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .frame(height: barHeight)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accent.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: centerRadius * 2 - 4, height: centerRadius * 2 - 4)
                .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 2)

            tabContent
        }
    }

    private var tabContent: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.leftTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }

            Button(action: onCommand) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: centerRadius * 2 + 28, height: barHeight)
            }

            ForEach(AppTab.rightTabs, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .frame(height: barHeight)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selected == tab ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Gallery

struct TabBarGallery: View {
    @State private var selectedE1: AppTab = .home
    @State private var selectedE2: AppTab = .chat
    @State private var selectedE3: AppTab = .workspace
    @State private var debugAngle: CGFloat = 30
    @State private var debugTension: CGFloat = 0.7
    @State private var debugGap: CGFloat = 14

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 48) {
                    Text("Metaball Tab Bar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    variantContainer("E1 — Neutral") {
                        TabBarMetaball(selected: $selectedE1, onCommand: {})
                            .padding(.horizontal, 16)
                    }

                    variantContainer("E2 — Glow") {
                        TabBarMetaballGlow(selected: $selectedE2, onCommand: {})
                            .padding(.horizontal, 16)
                    }

                    variantContainer("E3 — Filled") {
                        TabBarMetaballFilled(selected: $selectedE3, onCommand: {})
                            .padding(.horizontal, 16)
                    }

                    // Interactive shape debug
                    variantContainer("Shape debug") {
                        VStack(spacing: 12) {
                            MetaballTabBarShape(
                                centerRadius: 28,
                                gapWidth: debugGap,
                                connectionAngle: debugAngle,
                                neckTension: debugTension
                            )
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                            .frame(height: 56)
                            .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("angle: \(Int(debugAngle))°")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Slider(value: $debugAngle, in: 10...60)
                                }
                                HStack {
                                    Text("tension: \(debugTension, specifier: "%.2f")")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Slider(value: $debugTension, in: 0.3...1.2)
                                }
                                HStack {
                                    Text("gap: \(Int(debugGap))pt")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Slider(value: $debugGap, in: 6...30)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func variantContainer<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 20)

            content()
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Previews

#Preview("Gallery") {
    TabBarGallery()
}

#Preview("E1 — In context") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack {
            Spacer()
            TabBarMetaball(selected: .constant(.home), onCommand: {})
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("E2 — In context") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack {
            Spacer()
            TabBarMetaballGlow(selected: .constant(.chat), onCommand: {})
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("E3 — In context") {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack {
            Spacer()
            TabBarMetaballFilled(selected: .constant(.workspace), onCommand: {})
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
    .preferredColorScheme(.dark)
}
