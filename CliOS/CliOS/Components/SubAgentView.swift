import SwiftUI

// MARK: - Sub-Agent Notification View
//
// Shows when an agent spawns a sub-agent.
// Displays status (running / done) + typewriter task description.

struct SubAgentView: View {
    enum Status { case running, done }

    var taskText: String
    var status: Status = .running

    // Animation state — only used for .running
    @State private var displayedChars = 0
    @State private var glowBreath: CGFloat = 0
    @State private var dotPulse: CGFloat = 0
    @State private var headerOpacity: CGFloat = 0
    @State private var contentSlide: CGFloat = 6
    @State private var typeTimer: Timer?

    private let accent = Color(hex: "FF4D00")
    private let doneColor = Color(hex: "34D399")
    private var tint: Color { status == .running ? accent : doneColor }

    var body: some View {
        if status == .running {
            runningBody
        } else {
            doneBody
        }
    }

    // MARK: - Running (animated)

    private var runningBody: some View {
        let chars = Array(taskText)
        let visibleText = String(chars.prefix(displayedChars))
        let isTyping = displayedChars < chars.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12 + dotPulse * 0.18))
                        .frame(width: 18, height: 18)
                        .scaleEffect(1 + dotPulse * 0.25)

                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .opacity(0.7 + dotPulse * 0.3)
                }

                Text("sub-agent started")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .opacity(headerOpacity)
            .padding(.leading, 16)
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(0.55 + glowBreath * 0.30))
                    .frame(width: 2.5)

                Text(visibleText + (isTyping ? "▌" : ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .offset(y: contentSlide)
            .opacity(headerOpacity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { runEntrance() }
    }

    // MARK: - Done (static)

    private var doneBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(doneColor.opacity(0.22))
                        .frame(width: 18, height: 18)

                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(doneColor)
                }

                Text("sub-agent · done")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.leading, 16)
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(doneColor.opacity(0.55))
                    .frame(width: 2.5)

                Text(taskText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 16)
            .padding(.trailing, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Entrance animation

    private func runEntrance() {
        withAnimation(.easeOut(duration: 0.35)) {
            headerOpacity = 1
            contentSlide = 0
        }

        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            dotPulse = 1
        }

        let total = taskText.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            typeTimer = Timer.scheduledTimer(withTimeInterval: 0.020, repeats: true) { timer in
                displayedChars += 1
                if displayedChars >= total {
                    timer.invalidate()
                    typeTimer = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            glowBreath = 1
                        }
                    }
                }
            }
        }
    }
}
