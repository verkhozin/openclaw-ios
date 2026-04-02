import SwiftUI

struct ChatButtonsView: View {
    @Binding var isComposing: Bool
    @Binding var showCommands: Bool
    @State private var messageText = ""
    @State private var iconRotation: Double = 0
    @FocusState private var inputFocused: Bool
    @Namespace private var buttonNS

    private let btnHeight: CGFloat = 48
    private let transition = Animation.easeInOut(duration: 0.5)

    var body: some View {
        HStack(spacing: 8) {
            // MARK: - Left button (Back <-> Paperclip)

            if !showCommands {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: isComposing ? "paperclip" : "chevron.left")
                            .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                            .font(.system(size: isComposing ? 18 : 16, weight: .semibold))
                        if !isComposing {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .transition(.blurReplace)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: isComposing ? nil : .infinity, minHeight: btnHeight)
                }
                .buttonStyle(BounceButtonStyle())
                .frame(width: isComposing ? btnHeight : nil, height: btnHeight)
                .background(Color.white.opacity(0.12), in: isComposing ? AnyShape(Circle()) : AnyShape(Capsule()))
                .matchedGeometryEffect(id: "leftBtn", in: buttonNS)
                .transition(.blurReplace)
            }

            // MARK: - Middle (Slash + Search + Gap <-> TextField)

            if isComposing {
                TextField("Message", text: $messageText, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    .focused($inputFocused)
                    .matchedGeometryEffect(id: "centerArea", in: buttonNS)
                    .transition(.blurReplace)
            } else {
                HStack(spacing: 8) {
                    // Slash / Commands button
                    Button(action: {
                        let anim: Animation = showCommands
                            ? .spring(response: 0.35, dampingFraction: 0.92)
                            : .spring(response: 0.7, dampingFraction: 0.92)
                        if showCommands {
                            // Closing — rotate reverse
                            withAnimation(anim) {
                                iconRotation -= 360
                                showCommands = false
                            }
                        } else {
                            // Opening — bounce
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
                .matchedGeometryEffect(id: "centerArea", in: buttonNS)
                .transition(.blurReplace)
            }

            // MARK: - Right button (Reply <-> Send)

            if !showCommands {
                Button(action: {
                    if isComposing {
                        if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                            // TODO: send message
                            messageText = ""
                        }
                        withAnimation(transition) {
                            isComposing = false
                            inputFocused = false
                        }
                    } else {
                        withAnimation(transition) {
                            isComposing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            inputFocused = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isComposing ? "arrow.up" : "arrowshape.turn.up.left.fill")
                            .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                            .font(.system(size: isComposing ? 18 : 16, weight: isComposing ? .bold : .semibold))
                        if !isComposing {
                            Text("Reply")
                                .font(.system(size: 16, weight: .medium))
                                .transition(.blurReplace)
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: isComposing ? nil : .infinity, minHeight: btnHeight)
                }
                .buttonStyle(BounceButtonStyle())
                .frame(width: isComposing ? btnHeight : nil, height: btnHeight)
                .background(Color.white, in: isComposing ? AnyShape(Circle()) : AnyShape(Capsule()))
                .matchedGeometryEffect(id: "rightBtn", in: buttonNS)
                .transition(.blurReplace)
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

private struct BounceButtonStyle: ButtonStyle {
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

#Preview {
    ChatButtonsView(isComposing: .constant(false), showCommands: .constant(false))
        .frame(height: 120)
        .background(Color.black)
}
