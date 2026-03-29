import SwiftUI

struct ChatScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Minimum black panel height (handle + buttons + safe area)
    private let panelMin: CGFloat = 110
    // Maximum — how far up the panel can go (fraction of screen)
    private let panelMaxFraction: CGFloat = 0.7

    @State private var panelHeight: CGFloat = 110
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let panelMax = geo.size.height * panelMaxFraction
            let effectiveHeight = min(max(panelHeight - dragOffset, panelMin), panelMax)

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

                    VStack(spacing: 0) {
                        // Grab handle — drag target
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geo.size.width / 4, height: 5)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .updating($dragOffset) { value, state, _ in
                                        state = value.translation.height
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            let newHeight = panelHeight - value.translation.height
                                            panelHeight = min(max(newHeight, panelMin), panelMax)
                                        }
                                    }
                            )

                        // Buttons area
                        ChatButtonsView()
                            .frame(height: 68)
                            .padding(.bottom, Theme.paddingS)

                        // Extra space when panel is expanded
                        if effectiveHeight > panelMin + 20 {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: effectiveHeight)
                }
                .ignoresSafeArea(edges: .bottom)

                // Status bar fade: pure backdrop blur, no tint
                // Total height = safe area top + 80pt visible fade
                PureBlurView(style: .regular)
                    .frame(height: geo.safeAreaInsets.top + 80)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .mask(
                        VStack(spacing: 0) {
                            // Solid through entire safe area (behind status bar)
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: geo.safeAreaInsets.top)
                            // Then fade out over 80pt
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.3),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 80)
                            Spacer()
                        }
                    )
                    .ignoresSafeArea()

            }
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        }
    }

    private var statusBarColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

#Preview {
    ChatScreenView()
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
