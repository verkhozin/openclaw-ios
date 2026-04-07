import SwiftUI
import Combine

/// Manages in-app notification queue and presentation state.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// Currently displayed notification (nil = nothing showing).
    @Published var current: AppNotification?

    /// Whether the banner is expanded (tapped).
    @Published var isExpanded: Bool = false

    /// Set to true to trigger slide-up exit animation. Banner watches this.
    @Published var isDismissing: Bool = false

    private var queue: [AppNotification] = []
    private var autoDismissTask: Task<Void, Never>?

    private init() {}

    // MARK: - Public API

    func post(_ notification: AppNotification) {
        if notification.type == .connectionRestored,
           current?.type == .connectionLost {
            show(notification)
            return
        }

        if current != nil {
            queue.append(notification)
        } else {
            show(notification)
        }
    }

    func post(_ type: AppNotificationType, title: String, subtitle: String? = nil, style: AppNotificationStyle = .card) {
        post(AppNotification(type: type, style: style, title: title, subtitle: subtitle))
    }

    /// Start dismiss animation. Banner calls `finalizeDismiss()` when slide-up completes.
    func dismiss() {
        guard current != nil, !isDismissing else { return }
        autoDismissTask?.cancel()
        isDismissing = true
    }

    /// Called by the banner after the exit animation finishes.
    func finalizeDismiss() {
        current = nil
        isExpanded = false
        isDismissing = false
        // Show next after a short gap
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            showNext()
        }
    }

    func toggleExpanded() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
        if isExpanded, !(current?.type.isPersistent ?? false) {
            scheduleAutoDismiss(seconds: 6)
        }
    }

    // MARK: - Private

    private func show(_ notification: AppNotification) {
        autoDismissTask?.cancel()
        isDismissing = false
        isExpanded = false
        current = notification

        if !notification.type.isPersistent {
            scheduleAutoDismiss(seconds: 4)
        }
    }

    private func showNext() {
        guard current == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        show(next)
    }

    private func scheduleAutoDismiss(seconds: Double) {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }
}
