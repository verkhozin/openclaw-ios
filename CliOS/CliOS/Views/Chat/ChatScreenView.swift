import SwiftUI

struct ChatScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let panelMin: CGFloat = 48
    private let panelMaxFraction: CGFloat = 0.7

    @State private var panelHeight: CGFloat = 80
    @State private var keyboardHeight: CGFloat = 0
    @State private var isComposing = false
    @State private var showCommands = false
    @State private var commandsHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            let panelMax = geo.size.height * panelMaxFraction
            let commandsExtra: CGFloat = showCommands ? commandsHeight : 0
            // When composing, the black panel is just keyboard height — input bar lives in chat area
            let basePanelHeight = isComposing ? 0 : panelHeight + commandsExtra
            let panelWithKeyboard = basePanelHeight + keyboardHeight
            let effectiveHeight = min(max(panelWithKeyboard, panelMin), panelMax)
            let chatHeight = geo.size.height - effectiveHeight + geo.safeAreaInsets.top

            ZStack(alignment: .top) {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat area
                    ChatContentView()
                        .clipShape(
                            RoundedCornerShape(
                                corners: [.bottomLeft, .bottomRight],
                                radius: 45
                            )
                        )
                        .overlay(alignment: .bottom) {
                            // Input bar — only when composing, over chat frame
                            if isComposing {
                                ChatInputOverlay(
                                    isComposing: $isComposing,
                                    showCommands: $showCommands
                                )
                                .padding(.horizontal, Theme.paddingM)
                                .padding(.bottom, 20)
                                .transition(.blurReplace)
                            }
                        }
                        .frame(height: chatHeight)

                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: .top)

                // Black panel — buttons (non-composing) + commands
                if !isComposing {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: 12) {
                            Spacer(minLength: 0)

                            if showCommands {
                                CommandPillsView(isVisible: showCommands)
                                    .padding(.horizontal, Theme.paddingM)
                                    .transition(.opacity)
                            }

                            ChatButtonsView(isComposing: $isComposing, showCommands: $showCommands)
                        }
                        // Hidden measurer
                        .overlay {
                            CommandPillsView()
                                .padding(.horizontal, Theme.paddingM)
                                .hidden()
                                .background(
                                    GeometryReader { g in
                                        Color.clear.preference(
                                            key: CommandsHeightKey.self,
                                            value: g.size.height
                                        )
                                    }
                                )
                        }
                        .frame(height: effectiveHeight)
                        .padding(.bottom, bottomInset)
                        .clipped()
                        .background(Color.black)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

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
            .onPreferenceChange(CommandsHeightKey.self) { h in
                commandsHeight = h + 12 // +12 for spacing
            }
            .background(SwipeBackEnabler())
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
        .environmentObject(GatewayService.shared)
}

private struct CommandsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Command Pills

private struct CommandPillsView: View {
    var isVisible: Bool = true

    @State private var selectedModel = "Sonnet 4.6"
    @State private var thinkingLevel = 0
    @State private var fastMode = false
    @State private var visibleItems: Set<Int> = []

    private let models = ["Haiku 4.5", "Sonnet 4.6", "Opus 4.6"]
    private let thinkingLabels = ["Off", "Low", "Med", "High"]

    private let sections: [(title: String, subtitle: String)] = [
        ("Session", "Chat flow control"),
        ("Agent", "Model behavior"),
        ("Subagents", "Manage workers"),
        ("ACP", "Agent protocol"),
        ("Security", "Permissions & policy"),
        ("System", "Status & config"),
    ]

    private let totalItems = 10

    private func itemVisible(_ index: Int) -> Bool {
        visibleItems.contains(index)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Controls (indices 9, 8, 7 — top to bottom = last to appear)
            VStack(spacing: 14) {
                controlRow("Model") {
                    Button {
                        let current = models.firstIndex(of: selectedModel) ?? 0
                        let next = (current + 1) % models.count
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedModel = models[next]
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedModel)
                                .font(.system(size: 15, weight: .medium))
                                .contentTransition(.numericText())
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .staggerIn(visible: itemVisible(9))

                controlRow("Thinking") {
                    PillPicker(
                        options: thinkingLabels,
                        selection: $thinkingLevel
                    )
                }
                .staggerIn(visible: itemVisible(8))

                controlRow("Fast mode") {
                    Toggle("", isOn: $fastMode)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .staggerIn(visible: itemVisible(7))
            }

            // Divider (index 6)
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 16)
                .staggerIn(visible: itemVisible(6))

            // MARK: - Tile Grid (indices 5..0, mapped bottom-right to top-left)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(sections.enumerated()), id: \.element.title) { i, section in
                    Button(action: {}) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(section.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .staggerIn(visible: itemVisible(sections.count - 1 - i))
                }
            }
        }
        .onAppear {
            staggerIn()
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                staggerIn()
            } else {
                staggerOut()
            }
        }
    }

    private func staggerIn() {
        for i in 0..<totalItems {
            withAnimation(
                .spring(response: 0.55, dampingFraction: 0.8)
                .delay(0.05 * Double(i))
            ) {
                visibleItems.insert(i)
            }
        }
    }

    private func staggerOut() {
        // Reverse order: top items (highest index) disappear first
        for i in 0..<totalItems {
            let reverseIndex = totalItems - 1 - i
            withAnimation(
                .spring(response: 0.4, dampingFraction: 0.9)
                .delay(0.03 * Double(i))
            ) {
                visibleItems.remove(reverseIndex)
            }
        }
    }

    private func controlRow<C: View>(_ label: String, @ViewBuilder control: () -> C) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
            control()
        }
    }
}

private extension View {
    func staggerIn(visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.85)
            .offset(y: visible ? 0 : 12)
    }
}

// MARK: - Pill Picker

private struct PillPicker: View {
    let options: [String]
    @Binding var selection: Int
    @Namespace private var pillNS

    private let height: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = i
                    }
                } label: {
                    Text(options[i])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == i ? .black : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background {
                            if selection == i {
                                Capsule()
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "pill", in: pillNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: height)
        .background(Color.white.opacity(0.1), in: Capsule())
        .frame(width: 210)
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

// Re-enables the native swipe-back gesture when navigationBarHidden(true)
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    private class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
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
