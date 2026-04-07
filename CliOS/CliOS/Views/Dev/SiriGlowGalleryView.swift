import SwiftUI

/// Dev gallery for previewing SiriGlowBorder & SiriGlowRays with live controls.
struct SiriGlowGalleryView: View {
    // Shared
    @State private var intensity: CGFloat = 0.0
    @State private var speed: Double = 1.0
    @State private var cornerRadius: CGFloat = 28

    // Border params
    @State private var lineWidth: CGFloat = 3
    @State private var blurRadius: CGFloat = 14

    // Rays params
    @State private var rayLength: CGFloat = 40
    @State private var rayCount: Int = 14

    // Loader params
    @State private var loaderArc: CGFloat = 0.3
    @State private var loaderSpeed: Double = 1.0

    // Status demo
    @State private var demoStatus: SiriGlowStatus = .idle

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingL) {

                // MARK: - Mock pairing screen
                sectionTitle("Pairing Flow Mock")

                PairingMockView()
                    .frame(height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Status demo
                sectionTitle("Status View")

                ZStack {
                    Color.black
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    SiriGlowStatusView(status: demoStatus)
                }

                HStack(spacing: 12) {
                    statusButton("Idle", status: .idle)
                    statusButton("Loading", status: .loading)
                    statusButton("Connected", status: .connected)
                }


                // MARK: - Border demo
                sectionTitle("Border Glow")

                ZStack {
                    Color.black
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image("logoIconBlack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .siriGlow(
                            cornerRadius: cornerRadius,
                            lineWidth: lineWidth,
                            blurRadius: blurRadius,
                            intensity: intensity,
                            speed: speed
                        )
                }

                // MARK: - Loader demo
                sectionTitle("Loader")

                ZStack {
                    Color.black
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image("logoIconBlack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .siriLoader(
                            cornerRadius: cornerRadius,
                            lineWidth: lineWidth,
                            blurRadius: blurRadius,
                            intensity: intensity,
                            speed: loaderSpeed,
                            arcFraction: loaderArc
                        )
                }

                // MARK: - Rays demo
                sectionTitle("Ray Glow")

                ZStack {
                    Color.black
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image("logoIconBlack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .siriRays(
                            cornerRadius: cornerRadius,
                            rayCount: rayCount,
                            rayLength: rayLength,
                            intensity: intensity,
                            speed: speed
                        )
                }

                // MARK: - Combined (dark)
                sectionTitle("Border + Rays (Dark)")

                ZStack {
                    Color.black
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image("logoIconBlack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .siriGlow(
                            cornerRadius: cornerRadius,
                            lineWidth: lineWidth,
                            blurRadius: blurRadius,
                            intensity: intensity,
                            speed: speed
                        )
                        .siriRays(
                            cornerRadius: cornerRadius,
                            rayCount: rayCount,
                            rayLength: rayLength,
                            intensity: intensity,
                            speed: speed
                        )
                }

                // MARK: - Combined (light)
                sectionTitle("Border + Rays (Light)")

                ZStack {
                    Color.white
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image("logoIconWhite")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .siriGlow(
                            cornerRadius: cornerRadius,
                            lineWidth: lineWidth,
                            blurRadius: blurRadius,
                            intensity: intensity,
                            speed: speed
                        )
                        .siriRays(
                            cornerRadius: cornerRadius,
                            rayCount: rayCount,
                            rayLength: rayLength,
                            intensity: intensity,
                            speed: speed
                        )
                }

                // MARK: - Controls
                GroupBox {
                    VStack(spacing: 12) {
                        controlRow("Intensity", value: $intensity, range: 0...1)
                        controlRow("Speed", value: Binding(
                            get: { CGFloat(speed) },
                            set: { speed = Double($0) }
                        ), range: 0.1...4.0)
                        controlRow("Corner Radius", value: $cornerRadius, range: 0...60)

                        Divider().overlay(Theme.border)

                        Text("Border").font(Theme.fontCaption).foregroundColor(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        controlRow("Line Width", value: $lineWidth, range: 1...8)
                        controlRow("Blur", value: $blurRadius, range: 0...30)

                        Divider().overlay(Theme.border)

                        Text("Loader").font(Theme.fontCaption).foregroundColor(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        controlRow("Arc Size", value: $loaderArc, range: 0.05...0.8)
                        controlRow("Spin Speed", value: Binding(
                            get: { CGFloat(loaderSpeed) },
                            set: { loaderSpeed = Double($0) }
                        ), range: 0.2...4.0)

                        Divider().overlay(Theme.border)

                        Text("Rays").font(Theme.fontCaption).foregroundColor(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        controlRow("Ray Length", value: $rayLength, range: 10...100)
                        controlRow("Ray Count", value: Binding(
                            get: { CGFloat(rayCount) },
                            set: { rayCount = max(4, Int($0)) }
                        ), range: 4...30)
                    }
                } label: {
                    Text("Parameters")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textPrimary)
                }

                // MARK: - Quick actions
                HStack(spacing: 12) {
                    quickButton("Off") {
                        withAnimation(.easeOut(duration: 0.4)) { intensity = 0 }
                    }
                    quickButton("Subtle") {
                        withAnimation(.easeIn(duration: 0.6)) { intensity = 0.4 }
                    }
                    quickButton("Full") {
                        withAnimation(.easeIn(duration: 0.8)) { intensity = 1.0 }
                    }
                    quickButton("Pulse") {
                        startPulse()
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.top, Theme.paddingM)
        }
        .background(Theme.bg)
        .navigationTitle("Siri Glow")
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.fontTitle)
            .foregroundColor(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(Theme.fontMonoSmall)
                    .foregroundColor(Theme.textMuted)
            }
            Slider(value: value, in: range)
                .tint(Theme.accent)
        }
    }

    private func statusButton(_ title: String, status: SiriGlowStatus) -> some View {
        Button {
            withAnimation { demoStatus = status }
        } label: {
            Text(title)
                .font(Theme.fontCaption)
                .foregroundColor(demoStatus == status ? .black : Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(demoStatus == status ? Theme.accent : Theme.surface)
                .clipShape(Capsule())
        }
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.surface)
                .clipShape(Capsule())
        }
    }

    private func startPulse() {
        withAnimation(.easeIn(duration: 0.6)) { intensity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) { intensity = 0.3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.6)) { intensity = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.8)) { intensity = 0.3 }
        }
    }
}

#Preview {
    SiriGlowGalleryView()
}
