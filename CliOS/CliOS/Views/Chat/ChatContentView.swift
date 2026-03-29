import SwiftUI
import HighlightSwift

struct ChatContentView: View {
    private let sampleMessages: [(String, Bool)] = [
        ("Check email and tell me if anything urgent", true),
        ("On it.", false),
        ("Checked your inbox. **12 new emails**, 1 flagged urgent from *Gleb*.\n\n---\n\n**Urgent:** Gleb asks to reschedule tomorrow's sync to **Friday 3pm**.\n\n---\n\n**GitHub:** 3 PR reviews requested — `openclaw/gateway#42`, `openclaw/gateway#38`, `openclaw/clios#7`.\n\n---\n\n**Newsletters:** TechCrunch, Hacker News digest, Anthropic blog.\n\n---\n\nThe rest is noise. Want me to handle the reschedule?", false),
        ("Reschedule it, confirm with Gleb", true),
        ("Done.", false),
        ("Yeah push it", true),
        ("Deployed to `aurum.openclaw.dev`.\n\n---\n\nDNS propagated, SSL active.\n\n---\n\n**Lighthouse scores:**\n- Performance: **94**\n- Accessibility: **100**\n- Best Practices: **92**\n- SEO: **97**\n\n---\n\nLive in ~2 minutes.", false),
        ("How many tokens left today?", true),
        ("You've used **340k** of **500k** daily.\n\n---\n\n- Remaining: `160k`\n- Resets in: *4h 20m*\n- Current session: `28k` on Opus, `12k` on Sonnet\n\n---\n\nAt current rate you'll hit the cap in ~3 hours.", false),
        ("Show me the gateway config", true),
        ("Here's your current setup:\n\n```swift\nimport Foundation\n\nstruct GatewayConfig {\n    let host = \"openclaw.local\"\n    let port: UInt16 = 18789\n    let model: Model = .opus\n    let maxTokens = 500_000\n    let dailyReset = \"04:00 UTC\"\n\n    var wsURL: URL {\n        URL(string: \"ws://\\(host):\\(port)/ws\")!\n    }\n\n    var isLocal: Bool {\n        host.hasSuffix(\".local\")\n    }\n\n    func validate() throws {\n        guard port > 0 else {\n            throw ConfigError.invalidPort\n        }\n        guard !host.isEmpty else {\n            throw ConfigError.missingHost\n        }\n    }\n\n    enum ConfigError: Error {\n        case invalidPort\n        case missingHost\n    }\n}\n```\n\nWant me to change anything?", false),
    ]

    var body: some View {
        ZStack {
            // Chat background — slightly gray
            Color(.secondarySystemBackground)

            // Scrollable messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    Spacer().frame(height: 100)

                    ForEach(Array(sampleMessages.enumerated()), id: \.offset) { _, message in
                        ChatBubble(text: message.0, isUser: message.1)
                    }

                    Spacer().frame(height: 70)
                }
                .padding(.horizontal, Theme.paddingM)
            }
        }
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        let blocks = isUser ? [] : MessageParser.parse(text)
        let isCompact = !isUser && isCompactMessage(blocks)

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
            } else {
                // Agent reply — card style
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
            }
        }
    }
}

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
