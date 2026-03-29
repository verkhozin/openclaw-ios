import Foundation

/// Parses agent message text into renderable ContentBlocks.
///
/// Splits on fenced code blocks (``` ... ```) first, then parses
/// inline markdown within text segments. Code blocks with `card:*`
/// language tags produce `.card` blocks instead of `.code`.
enum MessageParser {

    // MARK: - Public

    /// Parse full message text into an ordered array of content blocks.
    /// Call once when streaming ends (phase: "end"), not on every delta.
    static func parse(_ text: String) -> [ContentBlock] {
        let segments = splitFencedBlocks(text)
        var blocks: [ContentBlock] = []

        for segment in segments {
            switch segment {
            case .text(let str):
                // Split on horizontal rules (---) to produce divider blocks
                let parts = str.components(separatedBy: "\n")
                var currentLines: [String] = []

                func flushText() {
                    let joined = currentLines.joined(separator: "\n")
                        .trimmingCharacters(in: .newlines)
                    if !joined.isEmpty {
                        let spans = parseInlineMarkdown(joined)
                        blocks.append(.text(attributed: spans))
                    }
                    currentLines = []
                }

                for line in parts {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                        flushText()
                        blocks.append(.divider())
                    } else {
                        currentLines.append(line)
                    }
                }
                flushText()

            case .fenced(let lang, let body):
                if lang.hasPrefix("card:") {
                    let cardType = String(lang.dropFirst(5)) // e.g. "github.pr"
                    let card = parseCard(type: cardType, body: body)
                    blocks.append(.card(serviceCard: card))
                } else {
                    blocks.append(.code(language: lang, code: body))
                }
            }
        }

        return blocks
    }

    // MARK: - Fenced block splitting

    private enum RawSegment {
        case text(String)
        case fenced(language: String, body: String)
    }

    /// Split text into alternating plain-text and fenced-code segments.
    private static func splitFencedBlocks(_ text: String) -> [RawSegment] {
        var segments: [RawSegment] = []
        var remaining = text[...]

        while let openRange = remaining.range(of: "```") {
            // Text before the fence
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
            if !before.isEmpty {
                segments.append(.text(before))
            }

            // After opening ```
            let afterOpen = remaining[openRange.upperBound...]

            // Language tag is everything up to the next newline
            let langEnd = afterOpen.firstIndex(of: "\n") ?? afterOpen.endIndex
            let language = String(afterOpen[afterOpen.startIndex..<langEnd])
                .trimmingCharacters(in: .whitespaces)

            let bodyStart = langEnd < afterOpen.endIndex
                ? afterOpen.index(after: langEnd)
                : afterOpen.endIndex

            // Find closing ```
            let bodySlice = afterOpen[bodyStart...]
            if let closeRange = bodySlice.range(of: "```") {
                let body = String(bodySlice[bodySlice.startIndex..<closeRange.lowerBound])
                    .trimmingCharacters(in: .newlines)
                segments.append(.fenced(language: language, body: body))
                remaining = bodySlice[closeRange.upperBound...]
            } else {
                // Unclosed fence — treat rest as code
                let body = String(bodySlice).trimmingCharacters(in: .newlines)
                segments.append(.fenced(language: language, body: body))
                break
            }
        }

        // Trailing text after last fence
        let trailing = String(remaining)
        if !trailing.isEmpty {
            segments.append(.text(trailing))
        }

        return segments
    }

    // MARK: - Inline markdown

    /// Parse inline markdown: **bold**, *italic*, `code`, ## headings, - bullets.
    static func parseInlineMarkdown(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []

        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                // Heading → bold
                let heading = String(trimmed.dropFirst(3))
                spans.append(.bold(heading))
            } else if trimmed.hasPrefix("# ") {
                let heading = String(trimmed.dropFirst(2))
                spans.append(.bold(heading))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                // Bullet → "• " prefix + inline parse
                let bullet = String(trimmed.dropFirst(2))
                spans.append(.plain("• "))
                spans.append(contentsOf: parseInlineSpans(bullet))
            } else {
                spans.append(contentsOf: parseInlineSpans(line))
            }

            // Add newline between lines (except last)
            if i < lines.count - 1 {
                spans.append(.plain("\n"))
            }
        }

        return spans
    }

    /// Parse bold, italic, inline code within a single line.
    private static func parseInlineSpans(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        var current = text[...]

        while !current.isEmpty {
            // Find the nearest marker
            let backtick = current.range(of: "`")
            let doubleStar = current.range(of: "**")
            let singleStar = current.range(of: "*")

            // Pick the earliest marker
            struct Marker {
                let type: MarkerType
                let range: Range<Substring.Index>
            }
            enum MarkerType { case code, bold, italic }

            var candidates: [Marker] = []
            if let r = backtick { candidates.append(Marker(type: .code, range: r)) }
            if let r = doubleStar { candidates.append(Marker(type: .bold, range: r)) }
            if let r = singleStar {
                // Only treat as italic if it's not part of **
                if doubleStar == nil || r.lowerBound != doubleStar!.lowerBound {
                    candidates.append(Marker(type: .italic, range: r))
                }
            }

            guard let first = candidates.min(by: { $0.range.lowerBound < $1.range.lowerBound }) else {
                // No markers left — rest is plain text
                spans.append(.plain(String(current)))
                break
            }

            // Plain text before the marker
            let before = String(current[current.startIndex..<first.range.lowerBound])
            if !before.isEmpty {
                spans.append(.plain(before))
            }

            let afterMarker = current[first.range.upperBound...]

            switch first.type {
            case .code:
                if let closeRange = afterMarker.range(of: "`") {
                    let code = String(afterMarker[afterMarker.startIndex..<closeRange.lowerBound])
                    spans.append(.inlineCode(code))
                    current = afterMarker[closeRange.upperBound...]
                } else {
                    spans.append(.plain("`"))
                    current = afterMarker
                }

            case .bold:
                if let closeRange = afterMarker.range(of: "**") {
                    let bold = String(afterMarker[afterMarker.startIndex..<closeRange.lowerBound])
                    spans.append(.bold(bold))
                    current = afterMarker[closeRange.upperBound...]
                } else {
                    spans.append(.plain("**"))
                    current = afterMarker
                }

            case .italic:
                if let closeRange = afterMarker.range(of: "*") {
                    let italic = String(afterMarker[afterMarker.startIndex..<closeRange.lowerBound])
                    spans.append(.italic(italic))
                    current = afterMarker[closeRange.upperBound...]
                } else {
                    spans.append(.plain("*"))
                    current = afterMarker
                }
            }
        }

        return spans
    }

    // MARK: - Card parsing

    /// Parse key:value pairs from card body. Lines before `---` are fields,
    /// lines after `---` are actions/metadata.
    private static func parseCard(type: String, body: String) -> ServiceCard {
        let cardType = ServiceCard.CardType(rawValue: type) ?? .unknown
        var fields: [String: String] = [:]

        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { continue }

            let parts = trimmed.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                fields[key] = value
            }
        }

        return ServiceCard(type: cardType, fields: fields)
    }
}
