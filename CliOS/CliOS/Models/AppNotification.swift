import SwiftUI

/// In-app notification types — drive icon, color, and auto-dismiss behavior.
enum AppNotificationType {
    case agentUpdate
    case taskComplete
    case taskFailed
    case connectionLost
    case connectionRestored
    case cronTriggered
    case system

    var icon: String {
        switch self {
        case .agentUpdate:        return "sparkles"
        case .taskComplete:       return "checkmark.circle.fill"
        case .taskFailed:         return "xmark.circle.fill"
        case .connectionLost:     return "wifi.slash"
        case .connectionRestored: return "wifi"
        case .cronTriggered:      return "clock.fill"
        case .system:             return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .agentUpdate:        return Color(hex: "FF4D00")
        case .taskComplete:       return Theme.success
        case .taskFailed:         return Theme.error
        case .connectionLost:     return Theme.error
        case .connectionRestored: return Theme.success
        case .cronTriggered:      return Theme.warning
        case .system:             return Theme.textSecondary
        }
    }

    /// Notifications that stick until manually dismissed or state changes.
    var isPersistent: Bool {
        self == .connectionLost
    }
}

/// Visual style for the notification banner.
enum AppNotificationStyle {
    /// Full-width black card dropping from the top edge.
    case card
    /// Pill / capsule under the Dynamic Island with liquid glass.
    case pill
}

/// A single in-app notification.
struct AppNotification: Identifiable {
    let id: UUID
    let type: AppNotificationType
    let style: AppNotificationStyle
    let title: String
    let subtitle: String?
    let timestamp: Date

    init(
        type: AppNotificationType,
        style: AppNotificationStyle = .card,
        title: String,
        subtitle: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.timestamp = Date()
    }
}
