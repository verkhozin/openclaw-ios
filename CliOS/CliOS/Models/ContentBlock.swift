import Foundation

/// A single renderable block parsed from agent message text.
/// One message may produce many blocks in sequence.
enum ContentBlock: Identifiable {
    case text(id: UUID = UUID(), attributed: [InlineSpan])
    case code(id: UUID = UUID(), language: String, code: String)
    case card(id: UUID = UUID(), serviceCard: ServiceCard)
    case divider(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .text(let id, _): id
        case .code(let id, _, _): id
        case .card(let id, _): id
        case .divider(let id): id
        }
    }
}

/// Inline styled span within a text block.
enum InlineSpan: Identifiable {
    case plain(id: UUID = UUID(), String)
    case bold(id: UUID = UUID(), String)
    case italic(id: UUID = UUID(), String)
    case inlineCode(id: UUID = UUID(), String)

    var id: UUID {
        switch self {
        case .plain(let id, _): id
        case .bold(let id, _): id
        case .italic(let id, _): id
        case .inlineCode(let id, _): id
        }
    }

    var text: String {
        switch self {
        case .plain(_, let s): s
        case .bold(_, let s): s
        case .italic(_, let s): s
        case .inlineCode(_, let s): s
        }
    }
}
