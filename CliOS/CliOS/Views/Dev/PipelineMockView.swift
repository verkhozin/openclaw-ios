import SwiftUI

// MARK: - Pipeline data models

struct PipelineAgent: Identifiable {
    let id: String
    let role: AgentRole
    let index: Int              // e.g. Qualifier #2
    let stage: Int              // column in the pipeline
    let model: String           // e.g. "sonnet 4.6"
    let status: AgentStatus
    let startedAt: Date?
    let endedAt: Date?

    // Detail fields
    let task: String            // what this agent is doing
    let sessionKey: String
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let log: [AgentLogEntry]

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

    var tokensFormatted: String {
        guard let t = totalTokens else { return "--" }
        if t >= 1000 { return String(format: "%.1fk", Double(t) / 1000) }
        return "\(t)"
    }
}

struct AgentLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let type: LogType

    enum LogType {
        case thinking    // agent reasoning
        case toolCall    // tool invocation
        case toolResult  // tool response (can be long, collapse)
        case error       // error
    }
}

enum AgentRole: String, CaseIterable {
    case coordinator = "Coordinator"
    case webResearcher = "Web Research"
    case dataAnalyst = "Data Analyst"
    case domainExpert = "Domain Expert"
    case synthesizer = "Synthesizer"
    case factChecker = "Fact Checker"
    case editor = "Editor"

    var tint: Color {
        switch self {
        case .coordinator:   return Color(hex: "A78BFA") // purple
        case .webResearcher: return Color(hex: "34D399") // green
        case .dataAnalyst:   return Color(hex: "60A5FA") // blue
        case .domainExpert:  return Color(hex: "FBBF24") // amber
        case .synthesizer:   return Color(hex: "F472B6") // pink
        case .factChecker:   return Color(hex: "FB923C") // orange
        case .editor:        return Color(hex: "C084FC") // light purple
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

    var color: Color {
        switch self {
        case .idle:         return Color(white: 0.25)
        case .transferring: return Color(hex: "60A5FA")
        }
    }
}

// MARK: - Agent Card

struct AgentCard: View {
    let agent: PipelineAgent
    static let cardWidth: CGFloat = 140
    static let cardHeight: CGFloat = 80

    private let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
    private let monoSmall = Font.system(size: 10, weight: .regular, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: role tag + status LED
            HStack(spacing: 0) {
                // Role tag like [SCOUT]
                Text("[\(agent.role.rawValue.uppercased())]")
                    .font(mono)
                    .foregroundColor(agent.role.tint)

                Spacer()

                // Status LED
                StatusLED(color: agent.status.color, isActive: agent.status == .running)
            }
            .padding(.bottom, 6)

            // Model
            Text(agent.model)
                .font(monoSmall)
                .foregroundColor(Color(white: 0.4))
                .padding(.bottom, 4)

            Spacer()

            // Bottom: runtime, right-aligned
            HStack(spacing: 4) {
                if agent.status == .running {
                    PulsingDot(color: agent.status.color)
                }

                Text(agent.runtimeFormatted)
                    .font(monoSmall)
                    .foregroundColor(statusTextColor)

                Spacer()

                Text(agent.status.rawValue.lowercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(agent.status.color.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
    }

    private var cardBg: Color {
        Color(white: 0.08)
    }

    private var borderColor: Color {
        switch agent.status {
        case .running: return agent.status.color.opacity(0.3)
        default:       return Color(white: 0.18)
        }
    }

    private var statusTextColor: Color {
        switch agent.status {
        case .running: return agent.status.color
        case .done:    return Theme.success.opacity(0.8)
        default:       return Color(white: 0.35)
        }
    }
}

// MARK: - Agent Detail Sheet

struct AgentDetailSheet: View {
    let agent: PipelineAgent
    private let blockBg = Color(white: 0.1)
    private let blockRadius: CGFloat = 8
    private let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    private let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    private let monoLabel = Font.system(size: 10, weight: .regular, design: .monospaced)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // Drag handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.3))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                // MARK: - Header block
                headerBlock

                // MARK: - Task block
                block {
                    sectionLabel("task")
                    Text(agent.task)
                        .font(monoSmall)
                        .foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: - Config block (editable feel)
                block {
                    sectionLabel("config")

                    configRow(label: "model", value: agent.model)
                    divider
                    configRow(label: "session", value: agent.sessionKey)
                }

                // MARK: - Stats block
                block {
                    sectionLabel("stats")

                    HStack(spacing: 0) {
                        statCell(label: "runtime", value: agent.runtimeFormatted)
                        statDivider
                        statCell(label: "tokens", value: agent.tokensFormatted)
                        if let start = agent.startedAt {
                            statDivider
                            statCell(label: "started", value: timeString(start))
                        }
                    }
                }

                // MARK: - Log block (fixed height, scrollable)
                if !agent.log.isEmpty {
                    logBlock
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.06))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerBlock: some View {
        HStack(spacing: 0) {
            Text("[\(agent.role.rawValue.uppercased())]")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(agent.role.tint)

            Text(" #\(agent.index)")
                .font(mono)
                .foregroundColor(Color(white: 0.4))

            Spacer()

            StatusLED(color: agent.status.color, isActive: agent.status == .running)

            Text(agent.status.rawValue.lowercased())
                .font(monoSmall)
                .foregroundColor(agent.status.color)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Log block

    private let logVisibleRows = 8
    private let logRowHeight: CGFloat = 48

    private var logBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("log")
                Spacer()
                Text("\(agent.log.count) entries")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(agent.log) { entry in
                            logRow(entry)
                                .padding(.vertical, 6)
                                .id(entry.id)
                            if entry.id != agent.log.last?.id {
                                divider
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(agent.log.count), CGFloat(logVisibleRows)) * logRowHeight)
                .onAppear {
                    if let last = agent.log.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockBg)
        .clipShape(RoundedRectangle(cornerRadius: blockRadius, style: .continuous))
    }

    // MARK: - Block container

    private func block<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockBg)
        .clipShape(RoundedRectangle(cornerRadius: blockRadius, style: .continuous))
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(white: 0.3))
            .kerning(1.2)
    }

    // MARK: - Config row (label: value, looks tappable)

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(monoLabel)
                .foregroundColor(Color(white: 0.4))

            Spacer()

            Text(value)
                .font(monoSmall)
                .foregroundColor(Theme.textPrimary)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.25))
        }
    }

    // MARK: - Stat cell

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Log row

    private func logRow(_ entry: AgentLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Color bar indicator
            RoundedRectangle(cornerRadius: 1)
                .fill(logColor(entry.type))
                .frame(width: 2, height: entry.type == .thinking ? 32 : 16)

            VStack(alignment: .leading, spacing: 2) {
                // Timestamp
                Text(timeString(entry.timestamp))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))

                // Text
                Text(entry.text)
                    .font(.system(size: 11, weight: entry.type == .thinking ? .light : .regular, design: .monospaced))
                    .foregroundColor(logTextColor(entry.type))
                    .lineLimit(entry.type == .thinking ? 4 : 2)
                    .italic(entry.type == .thinking)
            }
        }
    }

    private func logColor(_ type: AgentLogEntry.LogType) -> Color {
        switch type {
        case .thinking:   return Color(hex: "A78BFA")  // purple for thoughts
        case .toolCall:   return Color(hex: "60A5FA")  // blue
        case .toolResult: return Theme.success          // green
        case .error:      return Theme.error
        }
    }

    private func logTextColor(_ type: AgentLogEntry.LogType) -> Color {
        switch type {
        case .thinking:   return Color(white: 0.55)
        case .error:      return Theme.error.opacity(0.9)
        default:          return Color(white: 0.6)
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color(white: 0.15))
            .frame(height: 1)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(white: 0.18))
            .frame(width: 1, height: 28)
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}

// MARK: - Status LED with pulse

struct StatusLED: View {
    let color: Color
    let isActive: Bool

    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(isActive && breathing ? 1.8 : 1.0)
            .opacity(isActive && breathing ? 0.5 : 1.0)
            .animation(isActive ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: breathing)
            .onAppear {
                if isActive { breathing = true }
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

                // Pass 1: collect base wires into combined paths by type, stroke once each
                var idlePath = Path()
                var transferBasePath = Path()

                for wire in wires {
                    let p = WirePath.make(from: wire.from, to: wire.to)
                    switch wire.status {
                    case .idle:         idlePath.addPath(p)
                    case .transferring: transferBasePath.addPath(p)
                    }
                }

                context.stroke(idlePath, with: .color(Color(white: 0.25).opacity(0.3)), lineWidth: 2)
                context.stroke(transferBasePath, with: .color(Color(hex: "60A5FA").opacity(0.3)), lineWidth: 2)

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
    var onTapAgent: ((PipelineAgent) -> Void)? = nil

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
                        .onTapGesture { onTapAgent?(agent) }
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
    @State private var selectedAgent: PipelineAgent?

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            PipelineGraphView(agents: Self.mockAgents, wires: Self.mockWires) { agent in
                selectedAgent = agent
            }
            .padding(Theme.paddingM)
        }
        .background(Color.black)
        .navigationTitle("Pipeline")
        .preferredColorScheme(.dark)
        .sheet(item: $selectedAgent) { agent in
            AgentDetailSheet(agent: agent)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(white: 0.06))
        }
    }

    // MARK: - Mock data
    // Stage 0: Coordinator
    // Stage 1: Web Researcher, Data Analyst, Domain Expert
    // Stage 2: Synthesizer, Fact Checker
    // Stage 3: Editor
    //
    // Coordinator → 3 researchers → 2 processors → Editor

    private static let mockAgents: [PipelineAgent] = makeMockAgents()

    private static func makeMockAgents() -> [PipelineAgent] {
        let coordLog: [AgentLogEntry] = [
            AgentLogEntry(timestamp: Date().addingTimeInterval(-238), text: "The user wants a comprehensive research report on AI agent orchestration. I need to break this into parallel sub-tasks.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-230), text: "I'll split into three tracks: web research for recent publications, data analysis for trends, and domain expertise from our knowledge base.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-215), text: "spawn_agents([\"web_researcher\", \"data_analyst\", \"domain_expert\"])", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-210), text: "3 sub-agents spawned successfully", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-202), text: "All agents dispatched. Waiting for results to merge.", type: .thinking),
        ]

        let webLog: [AgentLogEntry] = [
            AgentLogEntry(timestamp: Date().addingTimeInterval(-193), text: "Starting with a broad search to identify the landscape of recent multi-agent research.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-188), text: "web_search(\"multi-agent systems orchestration survey 2026\")", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-180), text: "12 results returned. Top hits: arxiv.org/abs/2026.1234, deepmind.com/blog/...", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-175), text: "The arxiv paper looks most relevant — it's a survey of 47 orchestration frameworks. Let me pull the full text.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-160), text: "fetch_page(\"arxiv.org/abs/2026.1234\")", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-150), text: "Retrieved 14 pages. Key sections: taxonomy of patterns, benchmark results, limitations.", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-130), text: "Three key findings: (1) hierarchical beats flat in >5 agent scenarios, (2) tool-use latency is the bottleneck, (3) context sharing via shared memory outperforms message passing.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-100), text: "Let me also check the DeepMind blog post for a practitioner perspective.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-95), text: "fetch_page(\"deepmind.com/blog/agent-orchestration\")", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-85), text: "Blog post confirms survey findings. Adds practical recommendation: keep agent count under 8 for maintainability.", type: .toolResult),
        ]

        let dataLog: [AgentLogEntry] = [
            AgentLogEntry(timestamp: Date().addingTimeInterval(-190), text: "I need to analyze the metrics dataset to identify trends in agent performance over time.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-185), text: "read_file(\"data/metrics_2025.csv\")", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-170), text: "Loaded 2,847 rows, 14 columns. Columns: date, agent_count, latency_p50, latency_p99, tokens_total, cost_usd, success_rate...", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-160), text: "Interesting — there's a clear inflection point around March 2025 when success rates jumped from 72% to 91%. This coincides with the shift to structured outputs. I should highlight this.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-140), text: "code_exec(\"df.groupby('month')['success_rate'].mean().plot(); plt.savefig('trend.png')\")", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-110), text: "Chart saved. Shows clear upward trend with the March inflection.", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-80), text: "The cost data shows a 3x reduction per task after switching to Haiku for routing. Worth including in the summary.", type: .thinking),
        ]

        let domainLog: [AgentLogEntry] = [
            AgentLogEntry(timestamp: Date().addingTimeInterval(-190), text: "Searching our internal knowledge base for prior work on agent orchestration patterns.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-185), text: "vector_search(\"agent orchestration patterns\", top_k=10)", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-175), text: "10 chunks retrieved. Most relevant: internal RFC on pipeline design (score: 0.94), post-mortem from Q3 agent failure (score: 0.89).", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-160), text: "The RFC mentions we tried a flat topology initially and it failed at scale. This aligns with the coordinator's question about hierarchical vs flat. Let me dig deeper.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-140), text: "vector_search(\"flat vs hierarchical agent topology failure\", top_k=5)", type: .toolCall),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-125), text: "Found the Q3 post-mortem. Root cause: message passing overhead grew O(n^2) with flat topology at 12 agents.", type: .toolResult),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-100), text: "This is strong evidence for the hierarchical approach. Now I need to cross-reference with the coordinator's brief to ensure I'm covering all angles.", type: .thinking),
            AgentLogEntry(timestamp: Date().addingTimeInterval(-60), text: "The brief also asks about error recovery patterns. Let me search for that specifically...", type: .thinking),
        ]

        return [
            PipelineAgent(id: "coord", role: .coordinator, index: 1, stage: 0, model: "sonnet 4.6",
                          status: .done, startedAt: Date().addingTimeInterval(-240), endedAt: Date().addingTimeInterval(-200),
                          task: "Decompose research question into sub-tasks, assign to specialist agents",
                          sessionKey: "sess_a1b2c3", totalTokens: 1840, inputTokens: 620, outputTokens: 1220,
                          log: coordLog),

            PipelineAgent(id: "web", role: .webResearcher, index: 1, stage: 1, model: "sonnet 4.6",
                          status: .done, startedAt: Date().addingTimeInterval(-195), endedAt: Date().addingTimeInterval(-80),
                          task: "Search web for recent papers and articles on the topic, extract key findings",
                          sessionKey: "sess_d4e5f6", totalTokens: 5120, inputTokens: 1800, outputTokens: 3320,
                          log: webLog),

            PipelineAgent(id: "data", role: .dataAnalyst, index: 1, stage: 1, model: "opus 4.6",
                          status: .done, startedAt: Date().addingTimeInterval(-195), endedAt: Date().addingTimeInterval(-60),
                          task: "Analyze dataset trends, generate charts and statistical summary",
                          sessionKey: "sess_g7h8i9", totalTokens: 3400, inputTokens: 1200, outputTokens: 2200,
                          log: dataLog),

            PipelineAgent(id: "domain", role: .domainExpert, index: 1, stage: 1, model: "sonnet 4.6",
                          status: .running, startedAt: Date().addingTimeInterval(-195), endedAt: nil,
                          task: "RAG over internal knowledge base, cross-reference with coordinator brief",
                          sessionKey: "sess_j0k1l2", totalTokens: 4100, inputTokens: 2800, outputTokens: 1300,
                          log: domainLog),

            PipelineAgent(id: "synth", role: .synthesizer, index: 1, stage: 2, model: "opus 4.6",
                          status: .queued, startedAt: nil, endedAt: nil,
                          task: "Merge all research streams into unified report draft",
                          sessionKey: "sess_m3n4o5", totalTokens: nil, inputTokens: nil, outputTokens: nil,
                          log: []),

            PipelineAgent(id: "fact", role: .factChecker, index: 1, stage: 2, model: "haiku 4.5",
                          status: .queued, startedAt: nil, endedAt: nil,
                          task: "Verify claims, check citations, flag contradictions",
                          sessionKey: "sess_p6q7r8", totalTokens: nil, inputTokens: nil, outputTokens: nil,
                          log: []),

            PipelineAgent(id: "edit", role: .editor, index: 1, stage: 3, model: "opus 4.6",
                          status: .queued, startedAt: nil, endedAt: nil,
                          task: "Final polish, structure, tone alignment, format for delivery",
                          sessionKey: "sess_s9t0u1", totalTokens: nil, inputTokens: nil, outputTokens: nil,
                          log: []),
        ]
    }

    private static let mockWires: [WireConnection] = [
        // Coordinator → 3 researchers (fan-out)
        WireConnection(id: "w1", fromId: "coord", toId: "web", status: .idle),
        WireConnection(id: "w2", fromId: "coord", toId: "data", status: .idle),
        WireConnection(id: "w3", fromId: "coord", toId: "domain", status: .idle),

        // 3 researchers → Synthesizer (fan-in)
        WireConnection(id: "w4", fromId: "web", toId: "synth", status: .idle),
        WireConnection(id: "w5", fromId: "data", toId: "synth", status: .idle),
        WireConnection(id: "w6", fromId: "domain", toId: "synth", status: .transferring),

        // 3 researchers → Fact Checker (fan-in)
        WireConnection(id: "w7", fromId: "web", toId: "fact", status: .idle),
        WireConnection(id: "w8", fromId: "data", toId: "fact", status: .idle),
        WireConnection(id: "w9", fromId: "domain", toId: "fact", status: .transferring),

        // Synthesizer + Fact Checker → Editor (fan-in)
        WireConnection(id: "w10", fromId: "synth", toId: "edit", status: .idle),
        WireConnection(id: "w11", fromId: "fact", toId: "edit", status: .idle),
    ]
}

#Preview {
    PipelineMockView()
}
