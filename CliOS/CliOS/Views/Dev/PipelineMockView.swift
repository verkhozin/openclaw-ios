import SwiftUI

// MARK: - Pipeline data models

struct PipelineAgent: Identifiable {
    let id: String
    let role: AgentRole
    let index: Int              // e.g. Qualifier #2
    let stage: Int              // column in the pipeline
    let status: AgentStatus
    let startedAt: Date?
    let endedAt: Date?

    var runtime: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = endedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var runtimeFormatted: String {
        guard let rt = runtime else { return "--" }
        let mins = Int(rt / 60)
        let secs = Int(rt.truncatingRemainder(dividingBy: 60))
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    var displayName: String {
        "\(role.rawValue) #\(index)"
    }
}

enum AgentRole: String, CaseIterable {
    case scout = "Scout"
    case qualifier = "Qualifier"
    case designer = "Designer"
    case engineer = "Engineer"

    var icon: String {
        switch self {
        case .scout:     return "magnifyingglass"
        case .qualifier: return "checkmark.shield"
        case .designer:  return "paintbrush"
        case .engineer:  return "hammer"
        }
    }

    var tint: Color {
        switch self {
        case .scout:     return Color(hex: "A78BFA")
        case .qualifier: return Color(hex: "60A5FA")
        case .designer:  return Color(hex: "F472B6")
        case .engineer:  return Color(hex: "FB923C")
        }
    }
}

enum AgentStatus: String {
    case queued = "Queued"
    case running = "Running"
    case done = "Done"
    case failed = "Failed"

    var color: Color {
        switch self {
        case .queued:  return Theme.textMuted
        case .running: return Color(hex: "60A5FA")
        case .done:    return Theme.success
        case .failed:  return Theme.error
        }
    }

    var icon: String {
        switch self {
        case .queued:  return "clock"
        case .running: return "circle.dotted"
        case .done:    return "checkmark.circle.fill"
        case .failed:  return "xmark.circle.fill"
        }
    }
}

// MARK: - Wire connection

struct WireConnection: Identifiable {
    let id: String
    let fromId: String
    let toId: String
    let status: WireStatus
}

enum WireStatus {
    case idle           // gray, nothing happening
    case transferring   // animated pulse along wire
    case done           // solid green, data delivered

    var color: Color {
        switch self {
        case .idle:         return Color(white: 0.25)
        case .transferring: return Color(hex: "60A5FA")
        case .done:         return Theme.success
        }
    }
}

// MARK: - Agent Card

struct AgentCard: View {
    let agent: PipelineAgent
    static let cardWidth: CGFloat = 140
    static let cardHeight: CGFloat = 80

    var body: some View {
        VStack(spacing: 6) {
            // Large role icon
            Image(systemName: agent.role.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(agent.role.tint)

            // Role name + number
            Text(agent.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            // Runtime + status
            HStack(spacing: 4) {
                if agent.status == .running {
                    PulsingDot(color: agent.status.color)
                }

                Text(agent.runtimeFormatted)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textMuted)

                Image(systemName: agent.status.icon)
                    .font(.system(size: 10))
                    .foregroundColor(agent.status.color)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        switch agent.status {
        case .running: return agent.status.color.opacity(0.4)
        default:       return Theme.border
        }
    }
}

// MARK: - Pulsing dot

struct PulsingDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Pipeline layout constants

private enum PipelineLayout {
    static let cardW: CGFloat = AgentCard.cardWidth
    static let cardH: CGFloat = AgentCard.cardHeight
    static let gapH: CGFloat = 60      // horizontal gap between columns (wire space)
    static let gapV: CGFloat = 16      // vertical gap between cards in same column
    static let padLeft: CGFloat = 20
    static let padTop: CGFloat = 20

    /// X origin of a stage column
    static func columnX(stage: Int) -> CGFloat {
        padLeft + CGFloat(stage) * (cardW + gapH)
    }

    /// Card origin (top-left) — first card always at top, extras grow downward
    static func cardOrigin(stage: Int, row: Int) -> CGPoint {
        let x = columnX(stage: stage)
        let y = padTop + CGFloat(row) * (cardH + gapV)
        return CGPoint(x: x, y: y)
    }

    /// Right-center exit point of a card
    static func exitPoint(stage: Int, row: Int) -> CGPoint {
        let origin = cardOrigin(stage: stage, row: row)
        return CGPoint(x: origin.x + cardW, y: origin.y + cardH / 2)
    }

    /// Left-center entry point of a card
    static func entryPoint(stage: Int, row: Int) -> CGPoint {
        let origin = cardOrigin(stage: stage, row: row)
        return CGPoint(x: origin.x, y: origin.y + cardH / 2)
    }
}

// MARK: - Wire path helper

enum WirePath {
    /// Build an orthogonal (90° turns) path between two points
    static func make(from: CGPoint, to: CGPoint) -> Path {
        var p = Path()
        let midX = (from.x + to.x) / 2
        p.move(to: from)
        p.addLine(to: CGPoint(x: midX, y: from.y))
        p.addLine(to: CGPoint(x: midX, y: to.y))
        p.addLine(to: to)
        return p
    }

    /// Total length of the orthogonal path
    static func length(from: CGPoint, to: CGPoint) -> CGFloat {
        let midX = (from.x + to.x) / 2
        return abs(midX - from.x) + abs(to.y - from.y) + abs(to.x - midX)
    }

    /// Get a point at fractional distance along the path (0…1)
    static func point(at fraction: CGFloat, from: CGPoint, to: CGPoint) -> CGPoint {
        let midX = (from.x + to.x) / 2
        let h1 = abs(midX - from.x)
        let v  = abs(to.y - from.y)
        let h2 = abs(to.x - midX)
        let total = h1 + v + h2
        guard total > 0 else { return from }

        let dist = fraction * total

        if dist <= h1 {
            let t = dist / h1
            return CGPoint(x: from.x + (midX - from.x) * t, y: from.y)
        } else if dist <= h1 + v {
            let t = (dist - h1) / v
            return CGPoint(x: midX, y: from.y + (to.y - from.y) * t)
        } else {
            let t = (dist - h1 - v) / h2
            return CGPoint(x: midX + (to.x - midX) * t, y: to.y)
        }
    }
}

// MARK: - Resolved wire (positions pre-computed)

struct ResolvedWire {
    let from: CGPoint
    let to: CGPoint
    let status: WireStatus
    let length: CGFloat

    init(from: CGPoint, to: CGPoint, status: WireStatus) {
        self.from = from
        self.to = to
        self.status = status
        self.length = WirePath.length(from: from, to: to)
    }
}

// MARK: - Wire Canvas (single draw pass, no opacity stacking)

struct WireCanvas: View {
    let wires: [ResolvedWire]

    /// Fixed drop length in points
    private let dropPts: CGFloat = 24
    /// Speed in points per second (same visual speed for all wires)
    private let speed: CGFloat = 120

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Pass 1: collect base wires by status into combined paths, stroke once each
                var idlePath = Path()
                var transferBasePath = Path()
                var donePath = Path()

                for wire in wires {
                    let p = WirePath.make(from: wire.from, to: wire.to)
                    switch wire.status {
                    case .idle:         idlePath.addPath(p)
                    case .transferring: transferBasePath.addPath(p)
                    case .done:         donePath.addPath(p)
                    }
                }

                context.stroke(idlePath, with: .color(Color(white: 0.25).opacity(0.3)), lineWidth: 2)
                context.stroke(transferBasePath, with: .color(Color(hex: "60A5FA").opacity(0.3)), lineWidth: 2)
                context.stroke(donePath, with: .color(Theme.success), lineWidth: 2)

                // Pass 2: draw animated drops (transferring only)
                for wire in wires where wire.status == .transferring {
                    guard wire.length > 0 else { continue }

                    let frac = dropPts / wire.length
                    let cycleDuration = Double((wire.length + dropPts) / speed)
                    let phase = CGFloat(t.truncatingRemainder(dividingBy: cycleDuration)) / CGFloat(cycleDuration)
                    // Head goes from -frac to 1+frac
                    let head = -frac + phase * (1 + 2 * frac)
                    let tail = head - frac
                    let trimStart = max(0, min(1, tail))
                    let trimEnd = max(0, min(1, head))

                    guard trimEnd > trimStart else { continue }

                    // Build trimmed sub-path by sampling points
                    let steps = 20
                    var dropPath = Path()
                    for i in 0...steps {
                        let f = trimStart + (trimEnd - trimStart) * CGFloat(i) / CGFloat(steps)
                        let pt = WirePath.point(at: f, from: wire.from, to: wire.to)
                        if i == 0 { dropPath.move(to: pt) }
                        else { dropPath.addLine(to: pt) }
                    }

                    context.stroke(dropPath, with: .color(Color(hex: "60A5FA")),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                // Pass 3: entry dots
                for wire in wires {
                    let dotRect = CGRect(x: wire.to.x - 3, y: wire.to.y - 3, width: 6, height: 6)
                    context.fill(Circle().path(in: dotRect), with: .color(wire.status.color))
                }
            }
        }
    }

}

// MARK: - Pipeline Graph View

struct PipelineGraphView: View {
    let agents: [PipelineAgent]
    let wires: [WireConnection]

    private var stageMap: [Int: [PipelineAgent]] {
        Dictionary(grouping: agents, by: \.stage)
    }

    private var agentIndex: [String: (stage: Int, row: Int)] {
        var result: [String: (Int, Int)] = [:]
        for (stage, group) in stageMap {
            for (row, agent) in group.enumerated() {
                result[agent.id] = (stage, row)
            }
        }
        return result
    }

    private var resolvedWires: [ResolvedWire] {
        wires.compactMap { wire in
            guard let fromIdx = agentIndex[wire.fromId],
                  let toIdx = agentIndex[wire.toId] else { return nil }
            return ResolvedWire(
                from: PipelineLayout.exitPoint(stage: fromIdx.stage, row: fromIdx.row),
                to: PipelineLayout.entryPoint(stage: toIdx.stage, row: toIdx.row),
                status: wire.status
            )
        }
    }

    var body: some View {
        let maxStage = agents.map(\.stage).max() ?? 0
        let maxRows = stageMap.values.map(\.count).max() ?? 1
        let totalW = PipelineLayout.padLeft * 2 + CGFloat(maxStage + 1) * AgentCard.cardWidth + CGFloat(maxStage) * PipelineLayout.gapH
        let totalH = PipelineLayout.padTop * 2 + CGFloat(maxRows) * AgentCard.cardHeight + CGFloat(max(0, maxRows - 1)) * PipelineLayout.gapV

        ZStack(alignment: .topLeading) {
            // Single canvas for all wires — no opacity stacking
            WireCanvas(wires: resolvedWires)

            // Cards layer
            ForEach(agents) { agent in
                if let idx = agentIndex[agent.id] {
                    let origin = PipelineLayout.cardOrigin(stage: idx.stage, row: idx.row)
                    AgentCard(agent: agent)
                        .position(x: origin.x + AgentCard.cardWidth / 2,
                                  y: origin.y + AgentCard.cardHeight / 2)
                }
            }
        }
        .frame(width: totalW, height: totalH)
    }
}

// MARK: - Mock View

struct PipelineMockView: View {
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            PipelineGraphView(agents: Self.mockAgents, wires: Self.mockWires)
                .padding(Theme.paddingM)
        }
        .background(Color.black)
        .navigationTitle("Pipeline")
        .preferredColorScheme(.dark)
    }

    // MARK: - Mock data
    // Stage 0: Scout #1
    // Stage 1: Qualifier #1
    // Stage 2: Designer #1, #2
    // Stage 3: Engineer #1, #2, #3

    private static let mockAgents: [PipelineAgent] = [
        // 1 scout
        PipelineAgent(id: "s1", role: .scout, index: 1, stage: 0, status: .done,
                      startedAt: Date().addingTimeInterval(-180), endedAt: Date().addingTimeInterval(-60)),

        // 1 qualifier
        PipelineAgent(id: "q1", role: .qualifier, index: 1, stage: 1, status: .done,
                      startedAt: Date().addingTimeInterval(-55), endedAt: Date().addingTimeInterval(-10)),

        // 2 designers
        PipelineAgent(id: "d1", role: .designer, index: 1, stage: 2, status: .running,
                      startedAt: Date().addingTimeInterval(-8), endedAt: nil),
        PipelineAgent(id: "d2", role: .designer, index: 2, stage: 2, status: .running,
                      startedAt: Date().addingTimeInterval(-5), endedAt: nil),

        // 3 engineers
        PipelineAgent(id: "e1", role: .engineer, index: 1, stage: 3, status: .queued,
                      startedAt: nil, endedAt: nil),
        PipelineAgent(id: "e2", role: .engineer, index: 2, stage: 3, status: .queued,
                      startedAt: nil, endedAt: nil),
        PipelineAgent(id: "e3", role: .engineer, index: 3, stage: 3, status: .queued,
                      startedAt: nil, endedAt: nil),
    ]

    private static let mockWires: [WireConnection] = [
        // Scout → Qualifier (1:1)
        WireConnection(id: "w1", fromId: "s1", toId: "q1", status: .done),
        // Qualifier → Designers (1:2)
        WireConnection(id: "w2", fromId: "q1", toId: "d1", status: .transferring),
        WireConnection(id: "w3", fromId: "q1", toId: "d2", status: .transferring),
        // Designers → Engineers (2:3)
        WireConnection(id: "w4", fromId: "d1", toId: "e1", status: .idle),
        WireConnection(id: "w5", fromId: "d1", toId: "e2", status: .idle),
        WireConnection(id: "w6", fromId: "d2", toId: "e3", status: .idle),
    ]
}

#Preview {
    PipelineMockView()
}
