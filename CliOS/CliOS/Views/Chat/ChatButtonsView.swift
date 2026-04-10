import SwiftUI

struct ChatButtonsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gateway: GatewayService
    @Binding var isComposing: Bool
    @Binding var showCommands: Bool
    @State private var messageText = ""
    @State private var iconRotation: Double = 0
    @State private var inputFocused = false

    private let btnHeight: CGFloat = 48
    private let transition = Animation.easeInOut(duration: 0.5)

    var body: some View {
        HStack(spacing: 8) {
            // MARK: - Left button (Back <-> Paperclip)

            if !showCommands {
                if isComposing {
                    Button(action: { dismiss() }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolEffect(.appear, isActive: isComposing)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .frame(width: btnHeight, height: btnHeight)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .transition(.blurReplace)
                } else {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: btnHeight)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .transition(.blurReplace)
                }
            }

            // MARK: - Middle (Slash + Search + Gap <-> TextField)

            if isComposing {
                MentionTextView(
                    text: $messageText,
                    isFocused: $inputFocused
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                .transition(.blurReplace)
            } else {
                HStack(spacing: 8) {
                    // Slash / Commands button
                    Button(action: {
                        let anim: Animation = showCommands
                            ? .spring(response: 0.6, dampingFraction: 0.9)
                            : .spring(response: 0.7, dampingFraction: 0.9)
                        if showCommands {
                            withAnimation(anim) {
                                iconRotation -= 360
                                showCommands = false
                            }
                        } else {
                            withAnimation(anim) {
                                showCommands = true
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .symbolEffect(.bounce, value: showCommands)
                                .rotationEffect(.degrees(iconRotation))
                            if showCommands {
                                RevealText("Commands")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, showCommands ? 16 : 0)
                        .frame(minWidth: btnHeight, minHeight: btnHeight)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())

                    if !showCommands {
                        actionButton(icon: "magnifyingglass") {}
                            .transition(.blurReplace)

                        Color.clear.frame(width: btnHeight, height: btnHeight)
                            .transition(.blurReplace)
                    }
                }
                .transition(.blurReplace)
            }

            // MARK: - Right button (Reply <-> Send)

            if !showCommands {
                if isComposing {
                    let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    Button(action: {
                        if hasText {
                            gateway.sendMessage(messageText.trimmingCharacters(in: .whitespacesAndNewlines))
                            messageText = ""
                        }
                        withAnimation(transition) {
                            isComposing = false
                            inputFocused = false
                        }
                    }) {
                        Image(systemName: hasText ? "arrow.up" : "xmark")
                            .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(hasText ? .black : .white)
                            .symbolEffect(.appear, isActive: isComposing)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .frame(width: btnHeight, height: btnHeight)
                    .background(hasText ? Color.white : Color.white.opacity(0.12), in: Circle())
                    .animation(transition, value: hasText)
                    .transition(.blurReplace)
                } else {
                    Button(action: {
                        withAnimation(transition) {
                            isComposing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            inputFocused = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Reply")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: btnHeight)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .background(Color.white, in: Capsule())
                    .transition(.blurReplace)
                }
            }
        }
        .padding(.horizontal, Theme.paddingM)
        .frame(height: btnHeight)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(transition, value: isComposing)
    }

    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: btnHeight, height: btnHeight)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Bounce tap style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Character-by-character reveal

private struct RevealText: View {
    let fullText: String
    @State private var visibleCount = 0

    private let initialDelay: Double = 0.15
    private let charDelay: Double = 0.04

    init(_ text: String) {
        self.fullText = text
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(fullText.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .opacity(index < visibleCount ? 1 : 0)
            }
        }
        .onAppear {
            for i in 1...fullText.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay + charDelay * Double(i)) {
                    visibleCount = i
                }
            }
        }
        .onDisappear {
            visibleCount = 0
        }
    }
}

// MARK: - Chat Input Overlay (composing mode, lives in chat area)

struct ChatInputOverlay: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gateway: GatewayService
    @Binding var isComposing: Bool
    @Binding var showCommands: Bool
    @State private var messageText = ""
    @State private var inputFocused = false
    @StateObject private var mentionController = MentionTextController()
    @State private var mockMentionIndex = 0

    private let btnHeight: CGFloat = 48
    private let transition = Animation.easeInOut(duration: 0.5)

    var body: some View {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        HStack(alignment: .bottom, spacing: 8) {
            // Paperclip — mock mention insert
            Button(action: {
                let mocks: [(String, String, UIColor)] = [
                    ("readme.md", "doc.fill", .systemOrange),
                    ("Design Chat", "bubble.left.fill", .systemBlue),
                    ("Fix navbar #42", "checkmark.circle.fill", .systemGreen),
                    ("CodeAgent", "cpu.fill", .systemPurple),
                ]
                let mock = mocks[mockMentionIndex % mocks.count]
                mentionController.insertMention(name: mock.0, icon: mock.1, color: mock.2)
                mockMentionIndex += 1
            }) {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .symbolEffect(.bounce, value: isComposing)
            }
            .buttonStyle(BounceButtonStyle())
            .frame(width: btnHeight, height: btnHeight)
            .modifier(GlassCircleBackground())

            // MentionTextView
            MentionTextView(
                text: $messageText,
                isFocused: $inputFocused,
                textColor: UIColor.label,
                tintColor: UIColor.label,
                controller: mentionController
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: btnHeight)
            .modifier(GlassRoundedBackground(cornerRadius: 22))

            // Send / Close
            Button(action: {
                if hasText {
                    gateway.sendMessage(messageText.trimmingCharacters(in: .whitespacesAndNewlines))
                    messageText = ""
                }
                withAnimation(transition) {
                    isComposing = false
                    inputFocused = false
                }
            }) {
                Image(systemName: hasText ? "arrow.up" : "xmark")
                    .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(hasText ? Color(.systemBackground) : Color(.secondaryLabel))
                    .symbolEffect(.bounce, value: isComposing)
            }
            .buttonStyle(BounceButtonStyle())
            .frame(width: btnHeight, height: btnHeight)
            .modifier(SendButtonBackground(hasText: hasText))
            .animation(transition, value: hasText)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                inputFocused = true
            }
        }
    }
}

// MARK: - Glass Background Modifiers

private struct GlassCircleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

private struct SendButtonBackground: ViewModifier {
    let hasText: Bool

    func body(content: Content) -> some View {
        if hasText {
            content.background(Color(.label), in: Circle())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

private struct GlassRoundedBackground: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

#Preview {
    ChatButtonsView(isComposing: .constant(false), showCommands: .constant(false))
        .frame(height: 120)
        .background(Color.black)
}
