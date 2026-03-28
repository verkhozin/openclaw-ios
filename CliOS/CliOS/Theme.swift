import SwiftUI

enum Theme {
    // MARK: - Colors
    static let bg = Color(hex: "0A0A0A")
    static let surface = Color(hex: "141414")
    static let surfaceElevated = Color(hex: "1E1E1E")
    static let border = Color(hex: "2A2A2A")
    static let accent = Color(hex: "FF4D00")
    static let accentDim = Color(hex: "FF4D00").opacity(0.2)
    static let textPrimary = Color(hex: "F0F0F0")
    static let textSecondary = Color(hex: "888888")
    static let textMuted = Color(hex: "555555")
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FFD60A")
    static let error = Color(hex: "FF3B30")
    
    // MARK: - Typography
    static let fontHeadline = Font.system(.title, design: .default, weight: .bold)
    static let fontTitle = Font.system(.title2, design: .default, weight: .semibold)
    static let fontBody = Font.system(.body, design: .default)
    static let fontCaption = Font.system(.caption, design: .default)
    static let fontMono = Font.system(.body, design: .monospaced)
    static let fontMonoSmall = Font.system(.caption, design: .monospaced)
    
    // MARK: - Spacing
    static let paddingS: CGFloat = 8
    static let paddingM: CGFloat = 16
    static let paddingL: CGFloat = 24
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
