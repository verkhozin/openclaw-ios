import SwiftUI

struct ChatScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Minimum black panel height (buttons + padding + safe area)
    private let panelMin: CGFloat = 48
    // Maximum — how far up the panel can go (fraction of screen)
    private let panelMaxFraction: CGFloat = 0.7

    @State private var panelHeight: CGFloat = 65
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var isComposing = false
    @State private var showCommands = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            let panelMax = geo.size.height * panelMaxFraction
            let commandsExtra: CGFloat = showCommands ? 160 : 0
            let panelWithKeyboard = panelHeight + keyboardHeight + commandsExtra
            let effectiveHeight = min(max(panelWithKeyboard - dragOffset, panelMin), panelMax)

            ZStack(alignment: .top) {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat area — fills space above the black panel
                    ChatContentView()
                        .clipShape(
                            RoundedCornerShape(
                                corners: [.bottomLeft, .bottomRight],
                                radius: 45
                            )
                        )
                        .frame(height: geo.size.height - effectiveHeight + geo.safeAreaInsets.top)

                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: .top)

                // Black panel — anchored to bottom
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        Spacer(minLength: 0)

                        if showCommands {
                            CommandPillsView()
                                .padding(.horizontal, Theme.paddingM)
                        }

                        ChatButtonsView(isComposing: $isComposing, showCommands: $showCommands)
                    }
                    .frame(height: effectiveHeight)
                    .padding(.bottom, bottomInset)
                    .background(Color.black)
                }
                .ignoresSafeArea(edges: .bottom)

                // Status bar fade
                LinearGradient(
                    stops: [
                        .init(color: Color(.secondarySystemBackground), location: 0),
                        .init(color: Color(.secondarySystemBackground), location: 0.45),
                        .init(color: Color(.secondarySystemBackground).opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.safeAreaInsets.top + 50)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
                if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                    let curve = (notif.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
                    withAnimation(Self.keyboardAnimation(duration: duration, curve: curve)) {
                        keyboardHeight = frame.height - geo.safeAreaInsets.bottom
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notif in
                let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                let curve = (notif.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
                withAnimation(Self.keyboardAnimation(duration: duration, curve: curve)) {
                    keyboardHeight = 0
                }
            }
        }
    }

    private var statusBarColor: Color {
        colorScheme == .dark ? .black : .white
    }

    /// Matches the native iOS keyboard animation curve exactly
    static func keyboardAnimation(duration: Double, curve: UInt) -> Animation {
        // iOS keyboard uses UIViewAnimationCurve 7 — a custom spring-like curve
        // Best matched by a tight spring with no bounce
        if curve == 7 {
            return .interpolatingSpring(mass: 3.0, stiffness: 1000, damping: 500, initialVelocity: 0)
        }
        // Fallback for standard curves
        switch UIView.AnimationCurve(rawValue: Int(curve)) {
        case .easeIn: return .easeIn(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .linear: return .linear(duration: duration)
        default: return .easeInOut(duration: duration)
        }
    }
}

#Preview {
    ChatScreenView()
}

// MARK: - Command Pills

private struct CommandPillsView: View {
    private let commands = [
        ("envelope", "Check Email"),
        ("chart.bar", "Status"),
        ("hammer", "Run Build"),
        ("arrow.right.circle", "What's Next"),
        ("calendar", "Schedule"),
        ("brain", "Summarize"),
    ]

    @State private var visibleItems: Set<Int> = []

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: command.0)
                            .font(.system(size: 13, weight: .semibold))
                        Text(command.1)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(visibleItems.contains(index) ? 1 : 0.5)
                .opacity(visibleItems.contains(index) ? 1 : 0)
                .blur(radius: visibleItems.contains(index) ? 0 : 6)
            }
        }
        .onAppear {
            for i in commands.indices {
                withAnimation(
                    .spring(response: 0.5, dampingFraction: 0.6)
                    .delay(0.05 * Double(i))
                ) {
                    visibleItems.insert(i)
                }
            }
        }
        .onDisappear {
            visibleItems.removeAll()
        }
    }
}

/// Pure gaussian blur with no color tint — strips the vibrancy/tint sublayers
struct PureBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.backgroundColor = .clear
        // Remove the tint overlay that UIVisualEffectView adds
        DispatchQueue.main.async {
            stripTint(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}

    private func stripTint(from view: UIVisualEffectView) {
        // The tint lives in a private _UIVisualEffectSubview with a non-clear background
        for sub in view.subviews {
            for child in sub.subviews {
                if child.backgroundColor != nil && child.backgroundColor != .clear {
                    child.backgroundColor = .clear
                }
            }
        }
    }
}

// Custom shape to round only specific corners
struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
