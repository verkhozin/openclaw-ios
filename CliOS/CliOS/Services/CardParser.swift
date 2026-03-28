import Foundation

/// Parses ```card:type``` codeblocks from agent messages.
///
/// Format:
/// ```card:github.pr
/// repo: verkh-tech/site
/// title: Fix hero animation
/// status: merged
/// ---
/// actions: approve, edit, discard
/// ```
///
/// Returns clean text (card blocks removed) and parsed cards.
enum CardParser {
    
    struct Result {
        let cleanText: String
        let cards: [ServiceCard]
    }
    
    /// Extract service cards from message content
    static func parse(_ content: String) -> Result {
        var cards: [ServiceCard] = []
        var cleanText = content
        
        // Match ```card:type\n...\n```
        let pattern = "```card:(\\w+(?:\\.\\w+)*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return Result(cleanText: content, cards: [])
        }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        // Process in reverse so indices stay valid
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let typeStr = nsContent.substring(with: match.range(at: 1))
            let body = nsContent.substring(with: match.range(at: 2))
            let fullRange = match.range
            
            let cardType = ServiceCard.CardType(rawValue: typeStr) ?? .unknown
            let (fields, actions) = parseBody(body)
            
            var allFields = fields
            if !actions.isEmpty {
                allFields["_actions"] = actions.joined(separator: ",")
            }
            
            cards.append(ServiceCard(type: cardType, fields: allFields))
            
            // Remove card block from text
            let startIdx = cleanText.index(cleanText.startIndex, offsetBy: fullRange.location)
            let endIdx = cleanText.index(startIdx, offsetBy: fullRange.length)
            cleanText.removeSubrange(startIdx..<endIdx)
        }
        
        // Reverse cards so they're in document order
        cards.reverse()
        
        return Result(
            cleanText: cleanText.trimmingCharacters(in: .whitespacesAndNewlines),
            cards: cards
        )
    }
    
    /// Parse YAML-like body, split by --- separator
    private static func parseBody(_ body: String) -> (fields: [String: String], actions: [String]) {
        var fields: [String: String] = [:]
        var actions: [String] = []
        var inMeta = false
        
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "---" {
                inMeta = true
                continue
            }
            
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            if inMeta && key == "actions" {
                actions = value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            } else {
                fields[key] = value
            }
        }
        
        return (fields, actions)
    }
    
    /// Get actions from a parsed card's fields
    static func actions(from card: ServiceCard) -> [String] {
        guard let raw = card.fields["_actions"] else { return [] }
        return raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}
