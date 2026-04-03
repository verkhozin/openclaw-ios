import SwiftUI

/// Three dots that bounce in a wave pattern, like a typing indicator.
struct TypingDotsLoader: View {
    var color: Color = .white
    var dotSize: CGFloat = 8
    var spacing: CGFloat = 6

    @State private var active = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: active ? -8 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: active
                    )
            }
        }
        .onAppear { active = true }
        .onDisappear { active = false }
    }
}

#Preview {
    ZStack {
        Color(hex: "1A1A2E")
        TypingDotsLoader()
    }
}
