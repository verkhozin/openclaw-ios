import Foundation

/// Parses [card:type]...[/card] blocks from agent messages
enum CardParser {
    
    /// Extract service cards from message content
    static func parse(_ content: String) -> (cleanText: String, cards: [ServiceCard]) {
        var cards: [ServiceCard] = []
        var cleanText = content
        
        let pattern = #"\[card:(\w+\.?\w*)\]\n(.*?)\n\[/card\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return (content, [])
        }
        
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in matches.reversed() {
            guard let typeRange = Range(match.range(at: 1), in: content),
                  let bodyRange = Range(match.range(at: 2), in: content),
                  let fullRange = Range(match.range, in: content) else { continue }
            
            let typeStr = String(content[typeRange])
            let body = String(content[bodyRange])
            
            let cardType = ServiceCard.CardType(rawValue: typeStr) ?? .unknown
            var fields: [String: String] = [:]
            
            for line in body.components(separatedBy: "\n") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    fields[parts[0].trimmingCharacters(in: .whitespaces)] =
                        parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            cards.append(ServiceCard(type: cardType, fields: fields))
            cleanText.removeSubrange(fullRange)
        }
        
        return (cleanText.trimmingCharacters(in: .whitespacesAndNewlines), cards)
    }
}
