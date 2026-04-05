import SwiftUI

enum Theme {
    // MARK: - Colors (adaptive light/dark)
    static let bg = Color("bg")
    static let surface = Color("surface")
    static let surfaceElevated = Color("surfaceElevated")
    static let border = Color("border")
    static let accent = Color.white
    static let accentDim = Color.white.opacity(0.2)
    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")
    static let textMuted = Color("textMuted")
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
