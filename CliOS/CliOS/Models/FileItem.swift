import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String        // relative to workspace root
    let isDirectory: Bool
    let size: Int?          // bytes, nil for directories

    var type: FileType { FileType.from(filename: name) }

    var formattedSize: String? {
        guard let size else { return nil }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        switch type {
        case .html:        return "globe"
        case .markdown:    return "doc.text"
        case .code:        return "chevron.left.forwardslash.chevron.right"
        case .json:        return "curlybraces"
        case .image:       return "photo"
        case .pdf:         return "doc.richtext"
        case .unknown:     return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory { return .yellow }
        switch type {
        case .html:        return .blue
        case .markdown:    return .purple
        case .code:        return .green
        case .json:        return .orange
        case .image:       return .pink
        case .pdf:         return .red
        case .unknown:     return .gray
        }
    }
}

import SwiftUI

enum FileType: Hashable {
    case html
    case markdown
    case code(String)   // extension name
    case image
    case pdf
    case json
    case unknown

    static func from(filename: String) -> FileType {
        guard let ext = filename.split(separator: ".").last?.lowercased() else {
            return .unknown
        }
        switch ext {
        case "html", "htm":
            return .html
        case "md", "markdown":
            return .markdown
        case "swift", "ts", "tsx", "js", "jsx", "py", "rb", "go", "rs", "css", "scss",
             "sh", "bash", "zsh", "yaml", "yml", "toml", "xml", "c", "cpp", "h", "java", "kt":
            return .code(String(ext))
        case "json":
            return .json
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico", "heic":
            return .image
        case "pdf":
            return .pdf
        default:
            return .unknown
        }
    }
}
