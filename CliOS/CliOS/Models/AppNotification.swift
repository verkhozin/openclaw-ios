import SwiftUI

/// In-app notification types — drive icon, color, and auto-dismiss behavior.
enum AppNotificationType {
    case agentUpdate
    case taskComplete
    case taskFailed
    case connectionLost
    case connectionRestored
    case cronTriggered
    case newMessage
    case system

    var icon: String {
        switch self {
        case .agentUpdate:        return "sparkles"
        case .taskComplete:       return "checkmark.circle"
        case .taskFailed:         return "xmark.circle"
        case .connectionLost:     return "wifi.slash"
        case .connectionRestored: return "wifi"
        case .cronTriggered:      return "clock"
        case .newMessage:         return "bubble.left"
        case .system:             return "info.circle"
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
        case .newMessage:         return Theme.accent
        case .system:             return Theme.textSecondary
        }
    }

    var label: String {
        switch self {
        case .agentUpdate:        return "Agent"
        case .taskComplete:       return "Task Complete"
        case .taskFailed:         return "Task Failed"
        case .connectionLost:     return "Connection"
        case .connectionRestored: return "Connection"
        case .cronTriggered:      return "Cron"
        case .newMessage:         return "Message"
        case .system:             return "System"
        }
    }

    /// Notifications that stick until manually dismissed or state changes.
    var isPersistent: Bool {
        self == .connectionLost
    }

    /// Map a notify card's `kind` field to a notification type.
    static func from(notifyKind kind: String) -> AppNotificationType {
        switch kind.lowercased() {
        case "commit", "deploy", "agent", "agent.start", "agent.stop":
            return .agentUpdate
        case "task.done", "task.complete":
            return .taskComplete
        case "task.fail", "task.failed":
            return .taskFailed
        case "cron":
            return .cronTriggered
        default:
            return .system
        }
    }
}

/// Visual style for the notification banner.
enum AppNotificationStyle {
    /// Full-width black card dropping from the top edge.
    case card
    /// Pill / capsule under the Dynamic Island with liquid glass.
    case pill
    /// Rounded rectangle that expands from the Dynamic Island area.
    case island
}

/// A single in-app notification.
struct AppNotification: Identifiable {
    let id: UUID
    let type: AppNotificationType
    let style: AppNotificationStyle
    let title: String
    let subtitle: String?
    let timestamp: Date
    /// Session key for tap-to-navigate (cross-session and notify cards).
    let sessionKey: String?
    /// Visual card data for rich island notifications (notify.git, notify.workflow, notify.subagent).
    let visualCard: ServiceCard?

    init(
        type: AppNotificationType,
        style: AppNotificationStyle = .card,
        title: String,
        subtitle: String? = nil,
        sessionKey: String? = nil,
        visualCard: ServiceCard? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.timestamp = Date()
        self.sessionKey = sessionKey
        self.visualCard = visualCard
    }
}
