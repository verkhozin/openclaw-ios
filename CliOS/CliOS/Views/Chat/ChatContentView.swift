import SwiftUI
import HighlightSwift

struct ChatContentView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var initialMessageIDs: Set<UUID> = []
    @State private var appearedMessages: Set<UUID> = []
    @State private var isNearBottom = true

    private var messages: [Message] {
        gateway.sessionStore.currentMessages
    }

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        Spacer().frame(height: 100)

                        ForEach(messages) { message in
                            // Messages loaded from cache don't animate
                            let isInitial = initialMessageIDs.contains(message.id)
                            let isNew = !isInitial && !appearedMessages.contains(message.id)

                            ChatBubble(
                                text: message.content,
                                isUser: message.role == .user,
                                isStreaming: message.isStreaming
                            )
                            .animation(.easeInOut(duration: 0.25), value: message.content)
                            .animation(.easeInOut(duration: 0.25), value: message.isStreaming)
                            .id(message.id)
                            .offset(y: isNew ? 20 : 0)
                            .opacity(isNew ? 0 : 1)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = message.content
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                            .onAppear {
                                guard isNew else { return }
                                let delay: Double = message.role == .user ? 0 : 0.05
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(delay)) {
                                    appearedMessages.insert(message.id)
                                }
                            }
                        }

                        // Bottom anchor for scroll tracking
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear { isNearBottom = true }
                            .onDisappear { isNearBottom = false }

                        Spacer().frame(height: 70)
                    }
                    .padding(.horizontal, Theme.paddingM)
                }
                .onChange(of: messages.count) { _, _ in
                    guard isNearBottom, let last = messages.last else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: messages.last?.content) { _, _ in
                    guard isNearBottom,
                          let last = messages.last,
                          last.isStreaming else { return }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .onAppear {
            // Snapshot existing message IDs — these won't animate in
            initialMessageIDs = Set(messages.map(\.id))
        }
    }
}

// MARK: - Streaming Text View (character-by-character reveal)

struct StreamingTextView: View {
    let fullText: String
    let isStreaming: Bool
    @State private var revealedCount: Int = 0
    @State private var timer: Timer?

    var body: some View {
        Text(String(fullText.prefix(revealedCount)))
            .font(.system(size: 16))
            .onChange(of: fullText) { oldVal, newVal in
                if isStreaming && newVal.count > revealedCount {
                    animateNewCharacters(from: revealedCount, to: newVal.count)
                }
            }
            .onAppear {
                if isStreaming {
                    revealedCount = max(0, fullText.count - 1)
                    animateNewCharacters(from: revealedCount, to: fullText.count)
                } else {
                    revealedCount = fullText.count
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
            .onChange(of: isStreaming) { _, streaming in
                if !streaming {
                    timer?.invalidate()
                    timer = nil
                    revealedCount = fullText.count
                }
            }
    }

    private func animateNewCharacters(from start: Int, to end: Int) {
        timer?.invalidate()
        var current = start
        timer = Timer.scheduledTimer(withTimeInterval: 0.012, repeats: true) { t in
            if current < end {
                current += 1
                revealedCount = current
            } else {
                t.invalidate()
            }
        }
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    var isStreaming: Bool = false

    var body: some View {
        let showTyping = isStreaming && text.isEmpty
        let blocks = isUser ? [] : MessageParser.parse(text)
        let isCompact = !isUser && !showTyping && isCompactMessage(blocks)

        HStack {
            if isUser { Spacer(minLength: 60) }

            if isUser {
                Text(text)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .padding(.bottom, 10)
                    .background(BubbleTailShape(isUser: true).fill(Color(.label)))
                    .foregroundStyle(Color(.systemBackground))
            } else if showTyping {
                TypingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .transition(.opacity)

                Spacer(minLength: 40)
            } else if isStreaming {
                // Streaming agent reply — character reveal, no markdown parsing
                StreamingTextView(fullText: text, isStreaming: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            } else {
                // Final agent reply — full markdown
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                        switch block {
                        case .text(_, let spans):
                            buildAttributedText(spans)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        case .code(_, let language, let code):
                            CodeBlockView(language: language, code: code)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        case .card(_, let card):
                            Text("[\(card.type.rawValue) card]")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        case .divider:
                            Divider()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.vertical, 12)
                .fixedSize(horizontal: isCompact, vertical: false)
                .frame(maxWidth: isCompact ? nil : .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                if isCompact { Spacer(minLength: 40) }
            }
        }
    }

    private func isCompactMessage(_ blocks: [ContentBlock]) -> Bool {
        guard blocks.count == 1,
              case .text(_, let spans) = blocks[0] else { return false }
        let hasHeading = spans.contains { if case .heading = $0 { return true }; return false }
        guard !hasHeading else { return false }
        let totalLength = spans.reduce(0) { $0 + $1.text.count }
        let hasNewlines = spans.contains { $0.text.contains("\n") }
        return totalLength < 120 && !hasNewlines
    }

    private func buildAttributedText(_ spans: [InlineSpan]) -> Text {
        spans.reduce(Text("")) { result, span in
            switch span {
            case .plain(_, let s):
                result + Text(s)
                    .font(.system(size: 16))
            case .bold(_, let s):
                result + Text(s)
                    .font(.system(size: 16, weight: .semibold))
            case .italic(_, let s):
                result + Text(s)
                    .font(.system(size: 16))
                    .italic()
            case .inlineCode(_, let s):
                result + Text(s)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.secondary)
            case .heading(_, let level, let s):
                result + Text(s)
                    .font(.system(
                        size: level == 1 ? 22 : level == 2 ? 19 : 17,
                        weight: level <= 2 ? .bold : .semibold
                    ))
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 2)
                    .opacity(animating ? 0.9 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Code Block

struct CodeBlockView: View {
    let language: String
    let code: String

    @Environment(\.colorScheme) private var colorScheme

    private let collapsedMaxLines = 10
    private let collapsedHeight: CGFloat = 240

    @State private var isExpanded = false

    private var isLong: Bool {
        code.components(separatedBy: "\n").count > collapsedMaxLines
    }

    private var isDark: Bool { colorScheme == .dark }
    private var bgColor: Color { isDark ? Color(hex: "1E1E1E") : Color(hex: "F6F6F6") }
    private var tabColor: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }
    private var labelColor: Color { isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.45) }
    private var buttonTextColor: Color { isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.custom("JetBrainsMono-SemiBold", size: 14))
                        .foregroundStyle(labelColor)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(tabColor)
            }

            ZStack(alignment: .bottom) {
                codeTextView
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: (!isExpanded && isLong) ? collapsedHeight : nil, alignment: .top)
                    .clipped()

                if !isExpanded && isLong {
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true } }) {
                        ZStack(alignment: .bottom) {
                            PureBlurView(style: isDark ? .dark : .light)
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .black.opacity(0.6), location: 0.25),
                                            .init(color: .black, location: 0.5),
                                            .init(color: .black, location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            HStack(spacing: 4) {
                                Text("Show more")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(buttonTextColor)
                            .padding(.bottom, 10)
                        }
                        .frame(height: 70)
                    }
                    .buttonStyle(.plain)
                }

                if isExpanded && isLong {
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false } }) {
                        HStack(spacing: 4) {
                            Text("Show less")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(bgColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var codeTextView: some View {
        if let lang = HighlightLanguage(rawValue: language) {
            CodeText(code)
                .highlightLanguage(lang)
                .codeTextColors(.custom(dark: .dark(.atomOne), light: .light(.atomOne)))
                .font(.custom("JetBrainsMono-Regular", size: 13))
        } else {
            CodeText(code)
                .codeTextColors(.custom(dark: .dark(.atomOne), light: .light(.atomOne)))
                .font(.custom("JetBrainsMono-Regular", size: 13))
        }
    }
}

struct ChatNavBar: View {
    var body: some View {
        HStack(spacing: 0) {
            // Back button — separate circle
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .modifier(GlassNavBarModifier())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct GlassBubbleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.gray.opacity(0.15)), in: BubbleTailShape(isUser: false))
        } else {
            content
                .background(.ultraThinMaterial, in: BubbleTailShape(isUser: false))
        }
    }
}

struct GlassNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

/// Chat bubble shape with a small iMessage-style tail.
struct BubbleTailShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let cr: CGFloat = 20
        let th: CGFloat = 8   // tail height below body

        // Body occupies top portion; tail hangs below
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - th)

        var p = Path()

        // Start top-left, go clockwise
        p.move(to: CGPoint(x: body.minX + cr, y: body.minY))

        // Top edge
        p.addLine(to: CGPoint(x: body.maxX - cr, y: body.minY))

        // Top-right corner
        p.addArc(center: CGPoint(x: body.maxX - cr, y: body.minY + cr),
                 radius: cr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // Right edge
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - cr))

        if isUser {
            // Bottom-right: no rounded corner — flows into tail
            p.addLine(to: CGPoint(x: body.maxX, y: body.maxY))
            // Tail curves down and back
            p.addQuadCurve(to: CGPoint(x: body.maxX - 12, y: body.maxY),
                           control: CGPoint(x: body.maxX, y: body.maxY + th))
        } else {
            // Bottom-right corner (normal round)
            p.addArc(center: CGPoint(x: body.maxX - cr, y: body.maxY - cr),
                     radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }

        // Bottom edge
        if isUser {
            p.addLine(to: CGPoint(x: body.minX + cr, y: body.maxY))
        } else {
            p.addLine(to: CGPoint(x: body.minX + 12, y: body.maxY))
        }

        if !isUser {
            // Bottom-left: no rounded corner — flows into tail
            p.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY),
                           control: CGPoint(x: body.minX, y: body.maxY + th))
        } else {
            // Bottom-left corner (normal round)
            p.addArc(center: CGPoint(x: body.minX + cr, y: body.maxY - cr),
                     radius: cr, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }

        // Left edge
        if !isUser {
            p.addLine(to: CGPoint(x: body.minX, y: body.minY + cr))
        } else {
            p.addLine(to: CGPoint(x: body.minX, y: body.minY + cr))
        }

        // Top-left corner
        p.addArc(center: CGPoint(x: body.minX + cr, y: body.minY + cr),
                 radius: cr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        p.closeSubpath()
        return p
    }
}

struct ChatInputField: View {
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $text)
                .font(.system(size: 16))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.label))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .modifier(GlassInputModifier())
        .padding(.bottom, 16)
    }
}

struct GlassInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

#Preview {
    ChatContentView()
}
