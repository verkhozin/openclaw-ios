import UIKit
import SwiftUI

// MARK: - MentionAttachment

/// NSTextAttachment subclass that stores mention metadata and renders as a pill-shaped chip image.
/// The mention occupies a single character (\u{FFFC}) in the attributed string.
class MentionAttachment: NSTextAttachment {
    let mentionType: EntityType
    let entityId: String
    let displayName: String

    init(type: EntityType, entityId: String, displayName: String, font: UIFont) {
        self.mentionType = type
        self.entityId = entityId
        self.displayName = displayName
        super.init(data: nil, ofType: nil)

        let tintColor = UIColor(type.tint)
        let chipImage = Self.renderChip(name: displayName, icon: type.icon, tint: tintColor, font: font)
        self.image = chipImage

        let yOffset = (font.capHeight - chipImage.size.height) / 2
        self.bounds = CGRect(origin: CGPoint(x: 0, y: yOffset), size: chipImage.size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Chip rendering

    private static func renderChip(name: String, icon: String, tint: UIColor, font: UIFont) -> UIImage {
        let chipHeight = font.lineHeight
        let iconPointSize = font.pointSize * 0.7
        let labelFont = UIFont.systemFont(ofSize: font.pointSize - 1, weight: .medium)

        // Measure icon
        let config = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .semibold)
        let iconImage = UIImage(systemName: icon, withConfiguration: config)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        let iconSize = iconImage?.size ?? CGSize(width: iconPointSize, height: iconPointSize)

        // Measure text
        let textSize = (name as NSString).size(withAttributes: [.font: labelFont])

        // Layout constants
        let leadingPad: CGFloat = 6
        let iconTextGap: CGFloat = 3
        let trailingPad: CGFloat = 7

        let chipWidth = leadingPad + iconSize.width + iconTextGap + ceil(textSize.width) + trailingPad
        let chipSize = CGSize(width: ceil(chipWidth), height: chipHeight)

        let renderer = UIGraphicsImageRenderer(size: chipSize)
        return renderer.image { _ in
            // Pill background
            let pill = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: chipSize),
                cornerRadius: chipHeight / 2
            )
            tint.withAlphaComponent(0.15).setFill()
            pill.fill()

            // Icon
            if let iconImage {
                let iconY = (chipHeight - iconSize.height) / 2
                iconImage.draw(at: CGPoint(x: leadingPad, y: iconY))
            }

            // Label
            let textY = (chipHeight - textSize.height) / 2
            (name as NSString).draw(
                at: CGPoint(x: leadingPad + iconSize.width + iconTextGap, y: textY),
                withAttributes: [.font: labelFont, .foregroundColor: tint]
            )
        }
    }
}
