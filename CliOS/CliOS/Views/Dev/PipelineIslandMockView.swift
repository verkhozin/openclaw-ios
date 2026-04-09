import SwiftUI

// MARK: - Pipeline Stage Model (for island notification)

struct PipelineStage: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
    let status: PipelineStageStatus
    let startedAt: Date?
    let endedAt: Date?
    let task: String?

    var elapsed: TimeInterval? {
        guard let start = startedAt else { return nil }
        return (endedAt ?? Date()).timeIntervalSince(start)
    }

    var elapsedFormatted: String {
        guard let t = elapsed else { return "--" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "0:\(String(format: "%02d", s))"
    }
}

enum PipelineStageStatus: String {
    case completed, running, queued, failed
}

// MARK: - Handoff View (the visualization)

/// Pipeline progress visualization for Dynamic Island expansion.
/// "Handoff" layout: completed agents stacked left, running agent center-focused,
/// queued agents stacked right, with a thin progress track at the bottom.
struct PipelineHandoffView: View {
    let stages: [PipelineStage]

    // Animated elapsed time
    @State private var tick = Date()
    // Shimmer phase
    @State private var shimmerPhase: CGFloat = 0
    // Ring rotation
    @State private var ringRotation: Double = 0

    private var completedStages: [PipelineStage] {
        stages.filter { $0.status == .completed }
    }
    private var runningStage: PipelineStage? {
        stages.first { $0.status == .running }
    }
    private var queuedStages: [PipelineStage] {
        stages.filter { $0.status == .queued }
    }
    private var failedStage: PipelineStage? {
        stages.first { $0.status == .failed }
    }
    private var currentIndex: Int {
        stages.firstIndex { $0.status == .running || $0.status == .failed }
            ?? completedStages.count
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .top) {
                // Top fade — masks content near DI cutout
                topFade

                VStack(spacing: 0) {
                    // Main content row
                    mainRow(width: w)
                        .padding(.top, 14)

                    Spacer(minLength: 0)

                    // Progress track
                    progressTrack(width: w - 40)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(width: w, height: h)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    // MARK: - Top Fade

    private var topFade: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.6), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Main Row

    @ViewBuilder
    private func mainRow(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: completed agents
            leftStack
                .frame(width: 72, alignment: .leading)

            Spacer(minLength: 0)

            // Center: running agent (or failed)
            centerCard
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            // Right: queued agents
            rightStack
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Left Stack (completed)

    private var leftStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            let visible = completedStages.suffix(3)
            let hidden = completedStages.count - visible.count

            if hidden > 0 {
                Text("+ \(hidden)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.15))
            }

            ForEach(Array(visible)) { stage in
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(stage.tint.opacity(0.45))

                    Text(stage.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Center Card (running / failed)

    @ViewBuilder
    private var centerCard: some View {
        if let stage = runningStage ?? failedStage {
            let isRunning = stage.status == .running
            let tint = isRunning ? stage.tint : Color(hex: "FF3B30")

            VStack(spacing: 6) {
                // Top row: icon + name + elapsed
                HStack(spacing: 8) {
                    // Animated ring around icon
                    ZStack {
                        // Ring
                        Circle()
                            .trim(from: 0, to: isRunning ? 0.7 : 1)
                            .stroke(tint.opacity(isRunning ? 0.6 : 0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .rotationEffect(.degrees(isRunning ? ringRotation : 0))

                        Image(systemName: stage.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(tint)
                    }

                    Text(stage.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer(minLength: 4)

                    // Elapsed time
                    TimelineView(.animation(minimumInterval: 1)) { _ in
                        Text(stage.elapsedFormatted)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(tint.opacity(0.7))
                    }
                }

                // Task description
                if let task = stage.task {
                    Text(task)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 30)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.06))
            }
            .overlay(alignment: .leading) {
                // Left accent stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(0.5))
                    .frame(width: 2.5)
                    .padding(.vertical, 6)
            }
            .overlay(alignment: .bottom) {
                // Shimmer bar at bottom
                if isRunning {
                    shimmerBar(tint: tint, cornerRadius: 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if stages.allSatisfy({ $0.status == .completed }) {
            // All done
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "34C759"))

                Text("Pipeline Complete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Right Stack (queued)

    private var rightStack: some View {
        VStack(alignment: .trailing, spacing: 4) {
            let visible = queuedStages.prefix(3)
            let hidden = queuedStages.count - visible.count

            ForEach(Array(visible)) { stage in
                HStack(spacing: 5) {
                    Text(stage.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.12))
                        .lineLimit(1)

                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 5, height: 5)
                }
            }

            if hidden > 0 {
                Text("+ \(hidden)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.1))
            }
        }
    }

    // MARK: - Progress Track

    private func progressTrack(width: CGFloat) -> some View {
        let total = max(stages.count, 1)
        let progress = CGFloat(completedStages.count) / CGFloat(total)
        let runningProgress = runningStage != nil
            ? (CGFloat(completedStages.count) + 0.5) / CGFloat(total)
            : progress

        return HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.04))
                    .frame(height: 3)

                // Filled portion — gradient of completed stage colors
                GeometryReader { geo in
                    let filledW = geo.size.width * runningProgress
                    let colors = completedStages.map(\.tint)
                        + (runningStage.map { [$0.tint] } ?? [])

                    Capsule()
                        .fill(
                            colors.count > 1
                                ? LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [colors.first ?? .white], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(filledW, 3), height: 3)

                    // Bright dot at the end
                    if runningStage != nil, let tint = runningStage?.tint {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                            .shadow(color: tint.opacity(0.5), radius: 4)
                            .offset(x: filledW - 2.5, y: -1)
                    }
                }
                .frame(height: 5)
            }

            // Counter
            Text("\(completedStages.count)/\(total)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: - Shimmer Bar

    private func shimmerBar(tint: Color, cornerRadius: CGFloat) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let shimmerW: CGFloat = w * 0.4

            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [.clear, tint.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: shimmerW, height: 2)
                .offset(x: -shimmerW + (w + shimmerW) * shimmerPhase)
        }
        .frame(height: 2)
        .clipped()
    }
}

// MARK: - Mock View

struct PipelineIslandMockView: View {
    @State private var expanded = true
    @State private var scenarioIndex = 0

    // DI geometry (calibrated)
    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let contentHeight: CGFloat = 120

    private var currentScenario: PipelineScenario {
        PipelineScenario.all[scenarioIndex]
    }

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                // Dynamic Island frame
                GeometryReader { geo in
                    let screenW = geo.size.width
                    let expandedW = screenW - expandedHPad * 2
                    let currentW = expanded ? expandedW : diWidth
                    let currentCorner = expanded ? expandedCorner : diHeight / 2

                    VStack(spacing: 0) {
                        Color.clear.frame(height: diHeight)

                        if expanded {
                            PipelineHandoffView(stages: currentScenario.stages)
                                .frame(height: contentHeight)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: currentW)
                    .background(
                        RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                            .fill(Color.black)
                            .shadow(color: .black.opacity(expanded ? 0.6 : 0), radius: 24, y: 12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: currentCorner, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                            .strokeBorder(
                                (currentScenario.accentColor).opacity(expanded ? 0.12 : 0),
                                lineWidth: 0.5
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .offset(y: diTopY)
                }
                .frame(height: diTopY + diHeight + (expanded ? contentHeight : 0) + 30)
                .ignoresSafeArea(edges: .top)

                Spacer()

                // Controls
                controls
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            Text("PIPELINE PROGRESS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.25))

            // Scenario picker
            VStack(spacing: 8) {
                Text(currentScenario.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(currentScenario.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Scenario buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(PipelineScenario.all.enumerated()), id: \.offset) { i, scenario in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scenarioIndex = i
                            }
                        } label: {
                            Text(scenario.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(i == scenarioIndex ? .white : .white.opacity(0.35))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        i == scenarioIndex
                                            ? scenario.accentColor.opacity(0.15)
                                            : .white.opacity(0.04)
                                    )
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        i == scenarioIndex
                                            ? scenario.accentColor.opacity(0.3)
                                            : .clear,
                                        lineWidth: 0.5
                                    )
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Expand / Collapse
            Button {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
            } label: {
                Text(expanded ? "Collapse" : "Expand")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }
}

// MARK: - Mock Scenarios

private struct PipelineScenario {
    let label: String
    let title: String
    let subtitle: String
    let stages: [PipelineStage]

    var accentColor: Color {
        stages.first { $0.status == .running }?.tint
            ?? stages.first { $0.status == .failed }?.tint
            ?? Color(hex: "34C759")
    }

    static let all: [PipelineScenario] = [
        earlyStage,
        midStage,
        lateStage,
        failedStage,
        completedStage,
        sixStages,
    ]

    // 4 stages, stage 1 running
    static let earlyStage = PipelineScenario(
        label: "Early",
        title: "Lead Gen Pipeline",
        subtitle: "Stage 1 of 4 — Scout is enriching leads",
        stages: [
            PipelineStage(id: "s0", name: "Scout", icon: "magnifyingglass", tint: Color(hex: "34D399"), status: .running, startedAt: Date().addingTimeInterval(-42), endedAt: nil, task: "Enriching 12 Rivadata leads"),
            PipelineStage(id: "s1", name: "Qualifier", icon: "checkmark.shield", tint: Color(hex: "60A5FA"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
            PipelineStage(id: "s2", name: "Designer", icon: "paintbrush", tint: Color(hex: "F472B6"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
            PipelineStage(id: "s3", name: "Engineer", icon: "hammer", tint: Color(hex: "FBBF24"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
        ]
    )

    // 4 stages, stage 3 running
    static let midStage = PipelineScenario(
        label: "Mid",
        title: "Lead Gen Pipeline",
        subtitle: "Stage 3 of 4 — Designer building mockups",
        stages: [
            PipelineStage(id: "s0", name: "Scout", icon: "magnifyingglass", tint: Color(hex: "34D399"), status: .completed, startedAt: Date().addingTimeInterval(-310), endedAt: Date().addingTimeInterval(-195), task: "Enriched 12 leads"),
            PipelineStage(id: "s1", name: "Qualifier", icon: "checkmark.shield", tint: Color(hex: "60A5FA"), status: .completed, startedAt: Date().addingTimeInterval(-195), endedAt: Date().addingTimeInterval(-67), task: "Qualified 8 of 12"),
            PipelineStage(id: "s2", name: "Designer", icon: "paintbrush", tint: Color(hex: "F472B6"), status: .running, startedAt: Date().addingTimeInterval(-67), endedAt: nil, task: "Building React demo for Acme Corp"),
            PipelineStage(id: "s3", name: "Engineer", icon: "hammer", tint: Color(hex: "FBBF24"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
        ]
    )

    // 4 stages, stage 4 running
    static let lateStage = PipelineScenario(
        label: "Late",
        title: "Lead Gen Pipeline",
        subtitle: "Stage 4 of 4 — Engineer deploying",
        stages: [
            PipelineStage(id: "s0", name: "Scout", icon: "magnifyingglass", tint: Color(hex: "34D399"), status: .completed, startedAt: Date().addingTimeInterval(-480), endedAt: Date().addingTimeInterval(-365), task: nil),
            PipelineStage(id: "s1", name: "Qualifier", icon: "checkmark.shield", tint: Color(hex: "60A5FA"), status: .completed, startedAt: Date().addingTimeInterval(-365), endedAt: Date().addingTimeInterval(-197), task: nil),
            PipelineStage(id: "s2", name: "Designer", icon: "paintbrush", tint: Color(hex: "F472B6"), status: .completed, startedAt: Date().addingTimeInterval(-197), endedAt: Date().addingTimeInterval(-24), task: nil),
            PipelineStage(id: "s3", name: "Engineer", icon: "hammer", tint: Color(hex: "FBBF24"), status: .running, startedAt: Date().addingTimeInterval(-24), endedAt: nil, task: "Deploying demo to Vercel"),
        ]
    )

    // 4 stages, stage 2 failed
    static let failedStage = PipelineScenario(
        label: "Failed",
        title: "Lead Gen Pipeline",
        subtitle: "Qualifier failed — website audit timeout",
        stages: [
            PipelineStage(id: "s0", name: "Scout", icon: "magnifyingglass", tint: Color(hex: "34D399"), status: .completed, startedAt: Date().addingTimeInterval(-310), endedAt: Date().addingTimeInterval(-195), task: nil),
            PipelineStage(id: "s1", name: "Qualifier", icon: "checkmark.shield", tint: Color(hex: "FF3B30"), status: .failed, startedAt: Date().addingTimeInterval(-195), endedAt: Date().addingTimeInterval(-12), task: "Website audit timed out"),
            PipelineStage(id: "s2", name: "Designer", icon: "paintbrush", tint: Color(hex: "F472B6"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
            PipelineStage(id: "s3", name: "Engineer", icon: "hammer", tint: Color(hex: "FBBF24"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
        ]
    )

    // 4 stages, all completed
    static let completedStage = PipelineScenario(
        label: "Done",
        title: "Lead Gen Pipeline",
        subtitle: "All 4 stages completed in 7m 42s",
        stages: [
            PipelineStage(id: "s0", name: "Scout", icon: "magnifyingglass", tint: Color(hex: "34D399"), status: .completed, startedAt: Date().addingTimeInterval(-462), endedAt: Date().addingTimeInterval(-347), task: nil),
            PipelineStage(id: "s1", name: "Qualifier", icon: "checkmark.shield", tint: Color(hex: "60A5FA"), status: .completed, startedAt: Date().addingTimeInterval(-347), endedAt: Date().addingTimeInterval(-179), task: nil),
            PipelineStage(id: "s2", name: "Designer", icon: "paintbrush", tint: Color(hex: "F472B6"), status: .completed, startedAt: Date().addingTimeInterval(-179), endedAt: Date().addingTimeInterval(-24), task: nil),
            PipelineStage(id: "s3", name: "Engineer", icon: "hammer", tint: Color(hex: "FBBF24"), status: .completed, startedAt: Date().addingTimeInterval(-24), endedAt: Date(), task: nil),
        ]
    )

    // 6 stages — stress test
    static let sixStages = PipelineScenario(
        label: "6 Stages",
        title: "Research Pipeline",
        subtitle: "Stage 4 of 6 — Synthesizer merging results",
        stages: [
            PipelineStage(id: "s0", name: "Coordinator", icon: "cpu", tint: Color(hex: "A78BFA"), status: .completed, startedAt: Date().addingTimeInterval(-600), endedAt: Date().addingTimeInterval(-500), task: nil),
            PipelineStage(id: "s1", name: "Researcher", icon: "globe", tint: Color(hex: "34D399"), status: .completed, startedAt: Date().addingTimeInterval(-500), endedAt: Date().addingTimeInterval(-350), task: nil),
            PipelineStage(id: "s2", name: "Analyst", icon: "chart.bar", tint: Color(hex: "60A5FA"), status: .completed, startedAt: Date().addingTimeInterval(-350), endedAt: Date().addingTimeInterval(-180), task: nil),
            PipelineStage(id: "s3", name: "Synthesizer", icon: "arrow.triangle.merge", tint: Color(hex: "F472B6"), status: .running, startedAt: Date().addingTimeInterval(-180), endedAt: nil, task: "Merging 3 research streams"),
            PipelineStage(id: "s4", name: "Fact Check", icon: "checkmark.seal", tint: Color(hex: "FB923C"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
            PipelineStage(id: "s5", name: "Editor", icon: "pencil.line", tint: Color(hex: "C084FC"), status: .queued, startedAt: nil, endedAt: nil, task: nil),
        ]
    )
}

#Preview {
    PipelineIslandMockView()
        .preferredColorScheme(.dark)
}
