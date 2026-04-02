import SwiftUI

// MARK: - Word item for staggered animation

struct WordItem: Identifiable {
    let id: Int
    let text: String
    let isIcon: Bool
    let color: Color
    let isLineBreak: Bool

    init(id: Int, text: String, color: Color, isIcon: Bool = false, isLineBreak: Bool = false) {
        self.id = id
        self.text = text
        self.color = color
        self.isIcon = isIcon
        self.isLineBreak = isLineBreak
    }
}

// MARK: - Animated word flow

struct AnimatedWordFlow: View {
    let words: [WordItem]
    let font: Font
    let showContent: Bool
    let baseDelay: Double

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(words) { word in
                if word.isLineBreak {
                    // Force line break
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                } else if word.isIcon {
                    Image(systemName: word.text)
                        .foregroundColor(word.color)
                        .font(font)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(baseDelay + Double(word.id) * 0.06),
                            value: showContent
                        )
                } else {
                    Text(word.text)
                        .foregroundColor(word.color)
                        .font(font)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(baseDelay + Double(word.id) * 0.06),
                            value: showContent
                        )
                }
            }
        }
    }
}

// MARK: - Simple flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        // First pass: compute line widths for centering
        var lines: [[Int]] = [[]]
        var lineWidths: [CGFloat] = [0]
        var lineHeights: [CGFloat] = [0]

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            // Line break element
            if size.height == 0 && size.width >= maxWidth * 0.9 {
                lines.append([])
                lineWidths.append(0)
                lineHeights.append(0)
                continue
            }

            let widthNeeded = (lines.last!.isEmpty ? 0 : spacing) + size.width
            if !lines.last!.isEmpty && lineWidths.last! + widthNeeded > maxWidth {
                lines.append([])
                lineWidths.append(0)
                lineHeights.append(0)
            }

            lines[lines.count - 1].append(index)
            lineWidths[lineWidths.count - 1] += (lines.last!.count > 1 ? spacing : 0) + size.width
            lineHeights[lineHeights.count - 1] = max(lineHeights.last!, size.height)
        }

        // Second pass: place centered
        positions = Array(repeating: .zero, count: subviews.count)
        currentY = 0

        for (lineIndex, line) in lines.enumerated() {
            let lineW = lineWidths[lineIndex]
            let lineH = lineHeights[lineIndex]
            let offsetX = (maxWidth - lineW) / 2
            currentX = offsetX

            for index in line {
                let size = subviews[index].sizeThatFits(.unspecified)
                positions[index] = CGPoint(x: currentX, y: currentY)
                currentX += size.width + spacing
                maxX = max(maxX, currentX)
            }
            currentY += lineH + spacing
        }

        return (CGSize(width: maxWidth, height: currentY), positions)
    }
}

// MARK: - Expanded Overlay

struct AuroraExpandedOverlay: View {
    @Binding var isExpanded: Bool
    @Binding var showContent: Bool
    var gateway: GatewayService

    private let headlineFont: Font = .system(size: 36, weight: .heavy, design: .rounded)
    private let bodyFont: Font = .system(size: 24, weight: .bold, design: .rounded)
    private let bright: Color = .white
    private let dim: Color = .white.opacity(0.6)

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { collapse() }

            VStack(spacing: 36) {
                AnimatedWordFlow(
                    words: greetingWords,
                    font: headlineFont,
                    showContent: showContent,
                    baseDelay: 0.3
                )

                AnimatedWordFlow(
                    words: detailWords,
                    font: bodyFont,
                    showContent: showContent,
                    baseDelay: 0.7
                )
            }
            .padding(.horizontal, 24)

            // Close
            VStack {
                HStack {
                    Spacer()
                    Button { collapse() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 60)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(1.2), value: showContent)
                }
                Spacer()
            }
        }
    }

    private func collapse() {
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        // Trigger mask close immediately — mask handles its own timing
        isExpanded = false
    }

    // MARK: - Word lists

    private var greetingWords: [WordItem] {
        var i = 0
        func next() -> Int { defer { i += 1 }; return i }

        var words: [WordItem] = []

        // "Good evening."
        for w in greeting.split(separator: " ") {
            words.append(WordItem(id: next(), text: String(w), color: bright))
        }

        // line break
        words.append(WordItem(id: next(), text: "", color: .clear, isLineBreak: true))

        // clock icon + time + day
        words.append(WordItem(id: next(), text: "clock", color: dim, isIcon: true))
        words.append(WordItem(id: next(), text: timeString + ",", color: bright))
        words.append(WordItem(id: next(), text: dayOfWeek, color: bright))

        return words
    }

    private var detailWords: [WordItem] {
        var i = 0
        func next() -> Int { defer { i += 1 }; return i }

        var words: [WordItem] = []

        // tasks
        words.append(WordItem(id: next(), text: "tray.full.fill", color: dim, isIcon: true))
        words.append(WordItem(id: next(), text: "\(taskCount)", color: bright))
        words.append(WordItem(id: next(), text: taskCount == 1 ? "task" : "tasks", color: dim))

        // schedules
        words.append(WordItem(id: next(), text: "clock.arrow.trianglehead.counterclockwise.rotate.90", color: dim, isIcon: true))
        words.append(WordItem(id: next(), text: "\(cronCount)", color: bright))
        words.append(WordItem(id: next(), text: cronCount == 1 ? "schedule" : "schedules", color: dim))

        // line break
        words.append(WordItem(id: next(), text: "", color: .clear, isLineBreak: true))

        // connection status
        let connected = gateway.status.isConnected
        words.append(WordItem(id: next(), text: connected ? "bolt.fill" : "bolt.slash.fill",
                              color: connected ? .green : .red, isIcon: true))
        words.append(WordItem(id: next(), text: connected ? "Connected" : "Offline",
                              color: connected ? bright : dim))

        return words
    }

    // MARK: - Data

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default: return "Good night."
        }
    }

    private var dayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    private var taskCount: Int { gateway.tasks.count }
    private var cronCount: Int { gateway.cronJobs.count }
}
