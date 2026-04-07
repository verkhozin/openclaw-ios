import SwiftUI

// MARK: - Router

/// Routes to the correct banner style based on notification.style.
struct NotificationBanner: View {
    @ObservedObject var manager: NotificationManager

    var body: some View {
        if let notification = manager.current {
            Group {
                switch notification.style {
                case .card:
                    NotificationCardBanner(manager: manager)
                case .pill:
                    NotificationPillBanner(manager: manager)
                }
            }
            .zIndex(999)
        }
    }
}

// MARK: - Neumorphic Icon

/// Circle icon with outer white stroke, inner tint stroke, tinted fill, and
/// bottom-weighted inner shadow — neumorphism feel.
struct NeumorphicIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            // Inner shadow — stronger at bottom, weaker at top
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.5), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 4)
                .clipShape(Circle())

            // Outer white stroke
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: size, height: size)

            // Icon
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pill Banner (Liquid Glass)

/// Capsule pill under the Dynamic Island with liquid glass background.
struct NotificationPillBanner: View {
    @ObservedObject var manager: NotificationManager

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false
    @State private var timerProgress: CGFloat = 1

    var body: some View {
        if let notification = manager.current {
            pillContent(for: notification)
        }
    }

    @ViewBuilder
    private func pillContent(for notification: AppNotification) -> some View {
        // Pill sits right below safe area — no ignoresSafeArea needed
        HStack(spacing: 12) {
            NeumorphicIcon(
                systemName: notification.type.icon,
                tint: notification.type.tint,
                size: 38
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let subtitle = notification.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassBackground())
        .padding(.horizontal, 12)
        .offset(y: appeared ? 6 + min(dragOffset, 0) : -120)
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.height }
                .onEnded { value in
                    if value.translation.height < -30 {
                        manager.dismiss()
                    }
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture { manager.toggleExpanded() }
        .onAppear {
            appeared = false
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            startTimer(for: notification)
        }
        .onChange(of: manager.isDismissing) { _, dismissing in
            if dismissing {
                withAnimation(.easeIn(duration: 0.25)) {
                    appeared = false
                } completion: {
                    manager.finalizeDismiss()
                }
            }
        }
        .onChange(of: manager.current?.id) { _, _ in
            if let n = manager.current {
                startTimer(for: n)
            }
        }
    }

    private func startTimer(for notification: AppNotification) {
        timerProgress = 1
        guard !notification.type.isPersistent else { return }
        withAnimation(.linear(duration: 4)) {
            timerProgress = 0
        }
    }
}

/// Applies liquid glass on iOS 26+, falls back to ultraThinMaterial capsule.
struct LiquidGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Card Banner (existing)

/// Full-width black card that drops from the top screen edge.
struct NotificationCardBanner: View {
    @ObservedObject var manager: NotificationManager

    @State private var dragOffset: CGFloat = 0
    @State private var timerProgress: CGFloat = 1
    @State private var appeared = false

    private let bottomRadius: CGFloat = 20
    private let contentPadBelow: CGFloat = 48

    var body: some View {
        if manager.current != nil {
            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top
                let cardHeight = topInset + contentPadBelow + expandedExtra

                cardBody(height: cardHeight, width: geo.size.width)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var expandedExtra: CGFloat {
        var h: CGFloat = 80
        if manager.isExpanded { h += 50 }
        return h
    }

    @ViewBuilder
    private func cardBody(height: CGFloat, width: CGFloat) -> some View {
        if let notification = manager.current {
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: manager.isExpanded ? 6 : 3) {
                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(manager.isExpanded ? 3 : 1)

                    if let subtitle = notification.subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(manager.isExpanded ? Theme.textSecondary : Theme.textMuted)
                            .lineLimit(manager.isExpanded ? 4 : 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                if manager.isExpanded {
                    HStack(spacing: 12) {
                        Button {
                            manager.dismiss()
                        } label: {
                            Text("Dismiss")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.surface, in: Capsule())
                        }

                        Spacer()

                        if notification.type == .taskFailed {
                            Button {
                                manager.dismiss()
                            } label: {
                                Text("View Logs")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(notification.type.tint, in: Capsule())
                            }
                        }

                        Text(notification.timestamp, style: .time)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !notification.type.isPersistent {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(notification.type.tint.opacity(0.6))
                            .frame(width: geo.size.width * timerProgress, height: 2)
                    }
                    .frame(height: 2)
                    .padding(.top, 14)
                } else {
                    Spacer().frame(height: 14)
                }
            }
            .frame(width: width, height: height)
            .background {
                shape
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
            }
            .clipShape(shape)
            .overlay(alignment: .bottom) {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.clear, notification.type.tint.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
            }
            .offset(y: appeared ? min(dragOffset, 0) : -height)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        if value.translation.height < -40 {
                            manager.dismiss()
                        }
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
            )
            .onTapGesture { manager.toggleExpanded() }
            .onAppear {
                appeared = false
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
                startTimer(for: notification)
            }
            .onChange(of: manager.isDismissing) { _, dismissing in
                if dismissing {
                    withAnimation(.easeIn(duration: 0.3)) {
                        appeared = false
                    } completion: {
                        manager.finalizeDismiss()
                    }
                }
            }
            .onChange(of: manager.current?.id) { _, _ in
                if let n = manager.current {
                    startTimer(for: n)
                }
            }
        }
    }

    private func startTimer(for notification: AppNotification) {
        timerProgress = 1
        guard !notification.type.isPersistent else { return }
        let duration: Double = manager.isExpanded ? 6 : 4
        withAnimation(.linear(duration: duration)) {
            timerProgress = 0
        }
    }
}

// MARK: - View modifier

struct NotificationOverlayModifier: ViewModifier {
    @ObservedObject var manager: NotificationManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            NotificationBanner(manager: manager)
        }
    }
}

extension View {
    func notificationOverlay(_ manager: NotificationManager) -> some View {
        modifier(NotificationOverlayModifier(manager: manager))
    }
}
