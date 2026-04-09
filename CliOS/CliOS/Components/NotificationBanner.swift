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
                case .island:
                    NotificationIslandBanner(manager: manager)
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
            // Circle filled with semi-transparent tint
            Circle()
                .fill(tint.opacity(0.1))
                .frame(width: size, height: size)

            // Inner shadow — gradient from bottom edge, fading upward
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.4), tint.opacity(0.05)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 3
                )
                .blur(radius: 2.5)
                .clipShape(Circle())
                .frame(width: size, height: size)

            // Outer white stroke
            Circle()
                .strokeBorder(Color(UIColor { traits in
                    traits.userInterfaceStyle == .dark ? UIColor(white: 0.09, alpha: 1) : .white
                }), lineWidth: 1)
                .frame(width: size + 2, height: size + 2)

            // Thin tint stroke
            Circle()
                .strokeBorder(tint.opacity(0.3), lineWidth: 0.5)
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
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: manager.isExpanded ? 6 : 3) {
                    Text(notification.type.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(notification.type.tint)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(manager.isExpanded ? 3 : 1)

                    if let subtitle = notification.subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.6))
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
            .background(Color.black)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 6,
                bottomTrailingRadius: 6,
                topTrailingRadius: 0
            ))
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [.clear, notification.type.tint.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.5
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

// MARK: - Island Banner

/// Notification that expands from the Dynamic Island.
/// Top edge stays pinned at diTopY. Only bottom and sides grow.
struct NotificationIslandBanner: View {
    @ObservedObject var manager: NotificationManager

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false
    @State private var timerProgress: CGFloat = 1

    // Calibrated Dynamic Island geometry
    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let diCorner: CGFloat = 18  // half of diHeight ≈ capsule

    // Expanded
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let expandedTopGrow: CGFloat = 6  // how much it grows upward

    var body: some View {
        if let notification = manager.current {
            GeometryReader { geo in
                let screenW = geo.size.width
                let expandedW = screenW - expandedHPad * 2

                let currentW = appeared ? expandedW : diWidth
                let currentCorner = appeared ? expandedCorner : diCorner
                let currentTopY = appeared ? diTopY - expandedTopGrow : diTopY

                // Content: DI zone (hidden behind island) + visible content below
                VStack(spacing: 0) {
                    // Top part: matches DI height + extra top grow
                    Color.clear.frame(height: diHeight + (appeared ? expandedTopGrow : 0))

                    // Visible content below DI
                    if appeared {
                        islandContent(for: notification)
                            .transition(.opacity)
                    }
                }
                .frame(width: currentW)
                .background {
                    RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(appeared ? 0.5 : 0), radius: 20, y: 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: currentCorner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                        .strokeBorder(
                            notification.type.tint.opacity(appeared ? 0.15 : 0),
                            lineWidth: 0.5
                        )
                }
                // Pin top edge, centered horizontally
                .frame(maxWidth: .infinity, alignment: .top)
                .offset(y: currentTopY + min(dragOffset, 0))
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(999)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        if value.translation.height < -30 { manager.dismiss() }
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                    }
            )
            .onTapGesture { manager.toggleExpanded() }
            .onAppear {
                appeared = false
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    appeared = true
                }
                if let n = manager.current { startTimer(for: n) }
            }
            .onChange(of: manager.isDismissing) { _, dismissing in
                if dismissing {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        appeared = false
                    } completion: {
                        manager.finalizeDismiss()
                    }
                }
            }
            .onChange(of: manager.current?.id) { _, _ in
                if let n = manager.current { startTimer(for: n) }
            }
        }
    }

    /// Content height depends on whether this is a visual or text notification.
    private var contentHeight: CGFloat {
        guard let notification = manager.current else { return 100 }
        if let card = notification.visualCard {
            switch card.type {
            case .notifyGit:      return 130
            case .notifyWorkflow: return 120
            case .notifySubagent: return 120
            default:              return 100
            }
        }
        return 100
    }

    /// Expanded content — visual card or Live Activity style text.
    @ViewBuilder
    private func islandContent(for notification: AppNotification) -> some View {
        if let card = notification.visualCard {
            visualContent(for: card)
                .frame(height: contentHeight)
        } else {
            textContent(for: notification)
        }
    }

    /// Rich visual notification — GitGraphView, AgentClusterView, SubAgentView.
    @ViewBuilder
    private func visualContent(for card: ServiceCard) -> some View {
        switch card.type {
        case .notifyGit:
            GitGraphView(event: gitEvent(from: card))

        case .notifyWorkflow:
            AgentClusterView(
                workflowName: card.fields["workflow"] ?? "workflow",
                agentCount: Int(card.fields["agents"] ?? "6") ?? 6
            )

        case .notifySubagent:
            SubAgentView(
                taskText: card.fields["task"] ?? "",
                status: card.fields["status"] == "done" ? .done : .running
            )

        default:
            EmptyView()
        }
    }

    /// Build GitEvent from card fields.
    private func gitEvent(from card: ServiceCard) -> GitEvent {
        let typeStr = card.fields["type"] ?? "commit"
        let branch = card.fields["branch"] ?? "main"
        let source = card.fields["sourceBranch"] ?? "main"
        let commits = Int(card.fields["commits"] ?? "1") ?? 1
        let target = card.fields["deployTarget"] ?? ""

        let eventType: GitEventType
        switch typeStr {
        case "branch": eventType = .branchCreated
        case "deploy": eventType = .deployTriggered
        default:       eventType = .commitPushed
        }

        return GitEvent(
            type: eventType,
            branch: branch,
            sourceBranch: source,
            commitCount: commits,
            deployTarget: target
        )
    }

    /// Text-only island content — Live Activity style.
    @ViewBuilder
    private func textContent(for notification: AppNotification) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(notification.type.tint)

                    Text(notification.type.label.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(notification.type.tint)
                        .tracking(0.5)
                }

                Spacer(minLength: 12)

                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            if let subtitle = notification.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 46)
        }
    }

    private func startTimer(for notification: AppNotification) {
        timerProgress = 1
        guard !notification.type.isPersistent else { return }
        // Visual notifications get more time for animations to play
        let base: Double = notification.visualCard != nil ? 8 : 4
        let duration: Double = manager.isExpanded ? base + 2 : base
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
