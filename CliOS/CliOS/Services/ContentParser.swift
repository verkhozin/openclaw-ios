import Foundation

/// Parses raw message text into tags and metadata for SQLite storage.
/// Runs once per message at receive time — results are cached.
enum ContentParser {

    struct Result {
        let tags: [String]
        let hasCode: Bool
        let hasCard: Bool
        let cardType: String?
        let tagsJSON: String

        var parsedBlocksJSON: String? { nil } // TODO: serialize ContentBlock array when renderer needs it
    }

    /// Parse raw message content and extract tags/metadata.
    static func parse(_ content: String) -> Result {
        var tags: [String] = []
        var hasCode = false
        var hasCard = false
        var cardType: String?

        // Detect code blocks: ```language ... ```
        let codeBlockPattern = /```(\w+)?[\s\S]*?```/
        let codeMatches = content.matches(of: codeBlockPattern)
        if !codeMatches.isEmpty {
            hasCode = true
            tags.append("code")
            for match in codeMatches {
                if let lang = match.output.1 {
                    let langStr = String(lang).lowercased()
                    if !tags.contains(langStr) {
                        tags.append(langStr)
                    }
                }
            }
        }

        // Detect cards: [card:type]...[/card]
        let cardPattern = /\[card:(\w+\.?\w*)\]/
        let cardMatches = content.matches(of: cardPattern)
        if !cardMatches.isEmpty {
            hasCard = true
            tags.append("card")
            // Use the first card type found
            if let first = cardMatches.first {
                let typeStr = String(first.output.1)
                cardType = typeStr
                if !tags.contains(typeStr) {
                    tags.append(typeStr)
                }
            }
        }

        // Detect file/image references
        if content.contains("![") || content.range(of: #"\.(png|jpg|jpeg|gif|svg|pdf|mp4)"#, options: .regularExpression) != nil {
            if !tags.contains("file") {
                tags.append("file")
            }
        }

        let tagsJSON: String
        if let data = try? JSONEncoder().encode(tags), let str = String(data: data, encoding: .utf8) {
            tagsJSON = str
        } else {
            tagsJSON = "[]"
        }

        return Result(
            tags: tags,
            hasCode: hasCode,
            hasCard: hasCard,
            cardType: cardType,
            tagsJSON: tagsJSON
        )
    }
}
