import Foundation

/// Parses agent text into structured content blocks.
/// No UI -- just data models for rendering.
///
/// Handles: plain text, **bold**, *italic*, `inline code`,
/// ```codeblocks```, ```card:type``` blocks, bullet lists.
enum ContentParser {
    
    /// A block of content in an agent message
    enum Block: Identifiable {
        case text(TextRun)
        case codeBlock(CodeBlock)
        case card(ServiceCard)
        case bulletList([TextRun])
        
        var id: UUID {
            switch self {
            case .text(let t): return t.id
            case .codeBlock(let c): return c.id
            case .card(let c): return c.id
            case .bulletList: return UUID()
            }
        }
    }
    
    struct TextRun: Identifiable {
        let id = UUID()
        let segments: [Segment]
    }
    
    enum Segment {
        case plain(String)
        case bold(String)
        case italic(String)
        case code(String)          // inline `code`
        case link(text: String, url: String)
    }
    
    struct CodeBlock: Identifiable {
        let id = UUID()
        let language: String?
        let code: String
    }
    
    /// Parse full message content into blocks
    static func parse(_ content: String) -> [Block] {
        var blocks: [Block] = []
        var remaining = content
        
        while !remaining.isEmpty {
            // Try to find next code block or card block
            if let codeRange = findCodeBlock(in: remaining) {
                // Text before the code block
                let before = String(remaining[remaining.startIndex..<codeRange.fullRange.lowerBound])
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(contentsOf: parseTextBlocks(before))
                }
                
                if let cardType = codeRange.language, cardType.hasPrefix("card:") {
                    // Parse as service card
                    let typeStr = String(cardType.dropFirst(5))
                    let cardTypeEnum = ServiceCard.CardType(rawValue: typeStr) ?? .unknown
                    let (fields, _) = parseCardBody(codeRange.code)
                    blocks.append(.card(ServiceCard(type: cardTypeEnum, fields: fields)))
                } else {
                    // Regular code block
                    blocks.append(.codeBlock(CodeBlock(
                        language: codeRange.language,
                        code: codeRange.code
                    )))
                }
                
                remaining = String(remaining[codeRange.fullRange.upperBound...])
            } else {
                // No more code blocks, parse rest as text
                blocks.append(contentsOf: parseTextBlocks(remaining))
                remaining = ""
            }
        }
        
        return blocks
    }
    
    // MARK: - Code Block Detection
    
    private struct CodeBlockMatch {
        let fullRange: Range<String.Index>
        let language: String?
        let code: String
    }
    
    private static func findCodeBlock(in text: String) -> CodeBlockMatch? {
        // Find opening ```
        guard let openStart = text.range(of: "```") else { return nil }
        
        // Find the language (rest of the line after ```)
        let afterOpen = text[openStart.upperBound...]
        let lineEnd = afterOpen.firstIndex(of: "\n") ?? afterOpen.endIndex
        let language = String(afterOpen[afterOpen.startIndex..<lineEnd])
            .trimmingCharacters(in: .whitespaces)
        let lang = language.isEmpty ? nil : language
        
        // Find closing ```
        let codeStart = lineEnd < afterOpen.endIndex ? text.index(after: lineEnd) : lineEnd
        let searchRange = codeStart..<text.endIndex
        guard let closeRange = text.range(of: "```", range: searchRange) else { return nil }
        
        let code = String(text[codeStart..<closeRange.lowerBound])
            .trimmingCharacters(in: .newlines)
        
        let fullEnd = closeRange.upperBound
        return CodeBlockMatch(
            fullRange: openStart.lowerBound..<fullEnd,
            language: lang,
            code: code
        )
    }
    
    // MARK: - Text Block Parsing
    
    private static func parseTextBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var bulletItems: [TextRun] = []
        
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                bulletItems.append(parseInline(content))
            } else {
                // Flush bullet list if any
                if !bulletItems.isEmpty {
                    blocks.append(.bulletList(bulletItems))
                    bulletItems = []
                }
                
                if !trimmed.isEmpty {
                    blocks.append(.text(parseInline(trimmed)))
                }
            }
        }
        
        // Flush remaining bullets
        if !bulletItems.isEmpty {
            blocks.append(.bulletList(bulletItems))
        }
        
        return blocks
    }
    
    // MARK: - Inline Formatting
    
    /// Parse inline formatting: **bold**, *italic*, `code`, [link](url)
    static func parseInline(_ text: String) -> TextRun {
        var segments: [Segment] = []
        var remaining = text[text.startIndex...]
        
        while !remaining.isEmpty {
            // Find next special character
            if let match = findNextInline(in: remaining) {
                // Plain text before match
                if match.range.lowerBound > remaining.startIndex {
                    let plain = String(remaining[remaining.startIndex..<match.range.lowerBound])
                    segments.append(.plain(plain))
                }
                segments.append(match.segment)
                remaining = remaining[match.range.upperBound...]
            } else {
                // Rest is plain text
                segments.append(.plain(String(remaining)))
                remaining = remaining[remaining.endIndex...]
            }
        }
        
        return TextRun(segments: segments)
    }
    
    private struct InlineMatch {
        let range: Range<String.Index>
        let segment: Segment
    }
    
    private static func findNextInline(in text: Substring) -> InlineMatch? {
        var earliest: InlineMatch?
        
        // **bold**
        if let match = findDelimited(in: text, delimiter: "**", maker: { .bold($0) }) {
            if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }
        
        // *italic* (but not **)
        if let match = findDelimited(in: text, delimiter: "*", maker: { .italic($0) }) {
            // Make sure it's not part of **
            let idx = match.range.lowerBound
            let afterDelim = text.index(after: idx)
            if afterDelim < text.endIndex && text[afterDelim] == "*" {
                // This is **, skip
            } else if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }
        
        // `code`
        if let match = findDelimited(in: text, delimiter: "`", maker: { .code($0) }) {
            if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }
        
        return earliest
    }
    
    private static func findDelimited(
        in text: Substring,
        delimiter: String,
        maker: (String) -> Segment
    ) -> InlineMatch? {
        guard let openRange = text.range(of: delimiter) else { return nil }
        let afterOpen = text[openRange.upperBound...]
        guard let closeRange = afterOpen.range(of: delimiter) else { return nil }
        
        let content = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
        guard !content.isEmpty else { return nil }
        
        return InlineMatch(
            range: openRange.lowerBound..<closeRange.upperBound,
            segment: maker(content)
        )
    }
    
    // MARK: - Card Body (reused from CardParser)
    
    private static func parseCardBody(_ body: String) -> (fields: [String: String], actions: [String]) {
        var fields: [String: String] = [:]
        var actions: [String] = []
        var inMeta = false
        
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { inMeta = true; continue }
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            if inMeta && key == "actions" {
                actions = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                fields[key] = value
            }
        }
        
        return (fields, actions)
    }
}
