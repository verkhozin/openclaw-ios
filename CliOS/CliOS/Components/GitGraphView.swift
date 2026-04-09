import SwiftUI

// MARK: - Git Event Model

enum GitEventType {
    case branchCreated
    case commitPushed
    case deployTriggered
}

struct GitEvent {
    let type: GitEventType
    let branch: String
    let sourceBranch: String
    let commitCount: Int
    let deployTarget: String

    static let branchCreated = GitEvent(
        type: .branchCreated, branch: "feat/notifications",
        sourceBranch: "main", commitCount: 1, deployTarget: ""
    )
    static let oneCommit = GitEvent(
        type: .commitPushed, branch: "feat/notifications",
        sourceBranch: "main", commitCount: 1, deployTarget: ""
    )
    static let threeCommits = GitEvent(
        type: .commitPushed, branch: "feat/notifications",
        sourceBranch: "main", commitCount: 3, deployTarget: ""
    )
    static let twelveCommits = GitEvent(
        type: .commitPushed, branch: "feat/notifications",
        sourceBranch: "main", commitCount: 12, deployTarget: ""
    )
    static let deploy = GitEvent(
        type: .deployTriggered, branch: "feat/notifications",
        sourceBranch: "main", commitCount: 3, deployTarget: "staging"
    )
}

// MARK: - Shapes

struct HLine: Shape {
    var startX: CGFloat
    var endX: CGFloat
    var y: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: startX, y: y))
        p.addLine(to: CGPoint(x: endX, y: y))
        return p
    }
}

/// Fork path: starts at (startX, fromY) — same left edge as main line —
/// travels horizontally to forkX, then bezier curves up to (forkX + curveW, toY),
/// then continues horizontally to endX.
/// One continuous path — animate with .trim() for a smooth growing effect.
struct BranchForkPath: Shape {
    var startX: CGFloat  // left pad — same origin as gray line
    var forkX: CGFloat
    var fromY: CGFloat
    var toY: CGFloat
    var endX: CGFloat
    var curveW: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Horizontal run along main line until fork point
        p.move(to: CGPoint(x: startX, y: fromY))
        p.addLine(to: CGPoint(x: forkX, y: fromY))
        // Bezier: exits horizontally from forkX, arrives horizontally at branchY
        let cp1 = CGPoint(x: forkX + curveW * 0.65, y: fromY)
        let cp2 = CGPoint(x: forkX + curveW * 0.35, y: toY)
        p.addCurve(to: CGPoint(x: forkX + curveW, y: toY), control1: cp1, control2: cp2)
        // Continue horizontally to commit node
        p.addLine(to: CGPoint(x: endX, y: toY))
        return p
    }
}

// MARK: - Commit node

struct CommitNode: View {
    var color: Color
    var opacity: Double = 1.0
    var radius: CGFloat = 5
    var isHead: Bool = false
    var glowPulse: CGFloat = 0
    var appeared: Bool

    var body: some View {
        ZStack {
            if isHead {
                Circle()
                    .fill(color.opacity(0.08 + 0.12 * glowPulse))
                    .frame(width: 40, height: 40)
                    .blur(radius: 8)
            }
            Circle()
                .fill(.black)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .strokeBorder(color.opacity(opacity), lineWidth: 2.5)
                .frame(width: radius * 2, height: radius * 2)
            if isHead {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 4, height: 4)
            }
        }
        .scaleEffect(appeared ? 1 : 0.01)
        .opacity(appeared ? 1 : 0)
    }
}

// MARK: - Git Graph View

struct GitGraphView: View {
    let event: GitEvent

    // Shared animation state
    @State private var activeTrim: CGFloat = 0
    @State private var inactiveTrim: CGFloat = 0
    @State private var nodes: [Bool] = []
    @State private var headGlow: CGFloat = 0

    // Branch-created specific
    @State private var mainLineTrim: CGFloat = 0   // gray base line
    @State private var forkTrim: CGFloat = 0        // the fork path

    // Deploy specific
    @State private var deployDashTrim: CGFloat = 0
    @State private var deployNodeAppeared = false
    @State private var sweepX: CGFloat = 0

    // Labels
    @State private var labelOpacity: CGFloat = 0
    @State private var labelSlide: CGFloat = 6

    private let pad: CGFloat = 28
    private let mainY: CGFloat = 58   // base / source branch
    private let branchY: CGFloat = 30  // new branch (above)
    private let lineY: CGFloat = 50    // single-line events
    private let activeLineDuration: Double = 0.85
    private let curveW: CGFloat = 42   // bezier horizontal span

    private var accent: Color {
        switch event.type {
        case .branchCreated:   return Color(hex: "A78BFA")
        case .commitPushed:    return Color(hex: "34C759")
        case .deployTriggered: return Color(hex: "60A5FA")
        }
    }

    // Commit node x-offsets from left pad. Last node at ~75%.
    private func nodeOffsets(usableW: CGFloat) -> [CGFloat] {
        let end: CGFloat = usableW * 0.75
        switch event.commitCount {
        case 1:  return [end]
        case 3:  return [end - 60, end - 30, end]
        default: // 12
            let step = (end - usableW * 0.08) / 11
            return (0..<12).map { i in usableW * 0.08 + step * CGFloat(i) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let usableW = geo.size.width - pad * 2
            let offsets = nodeOffsets(usableW: usableW)
            let lastOffset = offsets.last ?? usableW * 0.75
            let activeEndX = pad + lastOffset
            let inactiveEndX = pad + usableW

            ZStack(alignment: .topLeading) {
                if event.type == .branchCreated {
                    branchCreatedGraph(usableW: usableW, lastOffset: lastOffset, inactiveEndX: inactiveEndX)
                } else {
                    standardGraph(usableW: usableW, offsets: offsets, activeEndX: activeEndX, inactiveEndX: inactiveEndX)
                }

                // Top fade to black
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.25), location: 0.55),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 18)
                .allowsHitTesting(false)

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: 3, height: 14)
                        Text(eventTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    Text(eventSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.leading, pad)
                .offset(y: 70)
                .opacity(labelOpacity)
                .offset(y: labelSlide)
            }
        }
        .onAppear { runEntrance() }
        .onChange(of: event.type) { _, _ in reset(); runEntrance() }
        .onChange(of: event.commitCount) { _, _ in reset(); runEntrance() }
    }

    // MARK: - Branch Created Graph
    //
    //      ● ──────────────────────   ← new branch (branchY, accent)
    //   /──
    // ─────────────────────────────   ← main/source (mainY, gray)

    @ViewBuilder
    private func branchCreatedGraph(usableW: CGFloat, lastOffset: CGFloat, inactiveEndX: CGFloat) -> some View {
        let forkX = pad + usableW * 0.20
        let branchNodeX = pad + lastOffset
        let forkEndX = forkX + curveW   // where bezier lands on branchY

        // Gray source (main) line — full width
        HLine(startX: pad, endX: inactiveEndX, y: mainY)
            .trim(from: 0, to: mainLineTrim)
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Fork path glow
        BranchForkPath(startX: pad, forkX: forkX, fromY: mainY, toY: branchY,
                       endX: branchNodeX, curveW: curveW)
            .trim(from: 0, to: forkTrim)
            .stroke(accent.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .blur(radius: 5)

        // Fork path — the new branch grows out
        BranchForkPath(startX: pad, forkX: forkX, fromY: mainY, toY: branchY,
                       endX: branchNodeX, curveW: curveW)
            .trim(from: 0, to: forkTrim)
            .stroke(
                LinearGradient(
                    colors: [accent.opacity(0.4), accent.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

        // Inactive continuation of new branch (after commit node)
        HLine(startX: branchNodeX, endX: inactiveEndX, y: branchY)
            .trim(from: 0, to: inactiveTrim)
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Commit node on branch
        if !nodes.isEmpty {
            CommitNode(
                color: accent, opacity: 1, radius: 6,
                isHead: true, glowPulse: headGlow,
                appeared: nodes[0]
            )
            .position(x: branchNodeX, y: branchY)
        }
    }

    // MARK: - Standard Graph (commit pushed / deploy)

    @ViewBuilder
    private func standardGraph(usableW: CGFloat, offsets: [CGFloat],
                                activeEndX: CGFloat, inactiveEndX: CGFloat) -> some View {
        // Glow behind active line
        HLine(startX: pad, endX: activeEndX, y: lineY)
            .trim(from: 0, to: activeTrim)
            .stroke(accent.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .blur(radius: 5)

        // Active colored line
        HLine(startX: pad, endX: activeEndX, y: lineY)
            .trim(from: 0, to: activeTrim)
            .stroke(
                LinearGradient(
                    colors: [accent.opacity(0.3), accent.opacity(0.75)],
                    startPoint: .leading, endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

        // Inactive gray line
        HLine(startX: activeEndX, endX: inactiveEndX, y: lineY)
            .trim(from: 0, to: inactiveTrim)
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Commit nodes
        ForEach(0..<offsets.count, id: \.self) { i in
            if i < nodes.count {
                let isHead = i == offsets.count - 1
                CommitNode(
                    color: accent,
                    opacity: isHead ? 1.0 : (event.commitCount == 12 && i < 9 ? 0.4 : 0.75),
                    radius: isHead ? 6 : (event.commitCount == 12 && i < 9 ? 3.5 : 5),
                    isHead: isHead,
                    glowPulse: isHead ? headGlow : 0,
                    appeared: nodes[i]
                )
                .position(x: pad + offsets[i], y: lineY)
            }
        }

        // Deploy extras
        if event.type == .deployTriggered {
            let deployX = activeEndX + 26

            HLine(startX: activeEndX + 4, endX: deployX - 12, y: lineY)
                .trim(from: 0, to: deployDashTrim)
                .stroke(Color(hex: "FFD60A").opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))

            ZStack {
                Circle()
                    .fill(Color(hex: "FFD60A").opacity(headGlow * 0.2))
                    .frame(width: 36, height: 36)
                    .blur(radius: 7)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black)
                    .frame(width: 18, height: 18)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(hex: "FFD60A").opacity(0.9), lineWidth: 2.5)
                    .frame(width: 18, height: 18)
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Color(hex: "FFD60A").opacity(0.75))
            }
            .scaleEffect(deployNodeAppeared ? 1 : 0.01)
            .opacity(deployNodeAppeared ? 1 : 0)
            .position(x: deployX, y: lineY)

            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, Color(hex: "FFD60A").opacity(0.18), .clear],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 90, height: 8)
                .blur(radius: 3)
                .position(x: sweepX, y: lineY)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Labels

    private var eventTitle: String {
        switch event.type {
        case .branchCreated:   return event.branch
        case .commitPushed:
            let s = event.commitCount == 1 ? "commit" : "commits"
            return "\(event.commitCount) \(s) pushed"
        case .deployTriggered: return "\(event.deployTarget) deploy"
        }
    }

    private var eventSubtitle: String {
        switch event.type {
        case .branchCreated:   return "branched from \(event.sourceBranch)"
        case .commitPushed:    return "\(event.branch) \u{2192} origin"
        case .deployTriggered: return "\(event.branch) \u{2192} \(event.deployTarget)"
        }
    }

    // MARK: - Animation

    private func reset() {
        activeTrim = 0
        inactiveTrim = 0
        mainLineTrim = 0
        forkTrim = 0
        nodes = []
        headGlow = 0
        deployDashTrim = 0
        deployNodeAppeared = false
        sweepX = 0
        labelOpacity = 0
        labelSlide = 6
    }

    private func runEntrance() {
        nodes = Array(repeating: false, count: event.commitCount)

        if event.type == .branchCreated {
            runBranchCreatedEntrance()
        } else {
            runStandardEntrance()
        }

        // Labels always fade in
        withAnimation(.easeOut(duration: 0.55).delay(0.45)) {
            labelOpacity = 1
            labelSlide = 0
        }
    }

    private func runBranchCreatedEntrance() {
        // 1) Gray main line draws quickly
        withAnimation(.easeOut(duration: 0.25)) {
            mainLineTrim = 1
        }

        // 2) Fork path grows: curve up + branch line — the hero moment
        withAnimation(.easeInOut(duration: 0.85).delay(0.35)) {
            forkTrim = 1
        }

        // 3) Commit node pops when fork path reaches it (~end of animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + 0.75) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                if !nodes.isEmpty { nodes[0] = true }
            }
        }

        // 4) Inactive continuation after node
        withAnimation(.easeOut(duration: 0.4).delay(0.35 + 0.85 + 0.1)) {
            inactiveTrim = 1
        }

        // 5) Head glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + 0.85 + 0.3) {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                headGlow = 1
            }
        }
    }

    private func runStandardEntrance() {
        let count = event.commitCount

        // 1) Active line grows
        withAnimation(.easeInOut(duration: activeLineDuration)) {
            activeTrim = 1
        }

        // 2) Nodes pop as line reaches them
        for i in 0..<count {
            let fraction = Double(i + 1) / Double(count + 1)
            let delay = fraction * (activeLineDuration - 0.15)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    if i < nodes.count { nodes[i] = true }
                }
            }
        }

        // 3) Inactive gray line grows after active finishes
        withAnimation(.easeOut(duration: 0.5).delay(activeLineDuration)) {
            inactiveTrim = 1
        }

        // 4) Head glow
        DispatchQueue.main.asyncAfter(deadline: .now() + activeLineDuration + 0.15) {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                headGlow = 1
            }
        }

        // 5) Deploy extras
        if event.type == .deployTriggered {
            let deployStart = activeLineDuration + 0.05
            withAnimation(.easeOut(duration: 0.4).delay(deployStart)) {
                deployDashTrim = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + deployStart + 0.35) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                    deployNodeAppeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + deployStart + 0.7) {
                let w = UIScreen.main.bounds.width
                sweepX = pad
                withAnimation(.easeInOut(duration: 1.0)) {
                    sweepX = w - pad
                }
            }
        }
    }
}
