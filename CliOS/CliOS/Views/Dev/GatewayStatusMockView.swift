import SwiftUI

/// Dev view to preview the Signal Field Radar gateway status visualization
/// inside a realistic Dynamic Island expansion frame.
struct GatewayStatusMockView: View {
    @State private var currentState: GatewayConnectionState = .reconnecting
    @State private var expanded = true
    @State private var mockLatency: Int = 47

    // Calibrated DI geometry (matches IslandCalibrationView)
    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let contentHeight: CGFloat = 130

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                // Dynamic Island frame
                GeometryReader { geo in
                    let screenW = geo.size.width
                    let expandedW = screenW - expandedHPad * 2
                    let currentW = expanded ? expandedW : diWidth
                    let currentCorner = expanded ? expandedCorner : diHeight / 2

                    VStack(spacing: 0) {
                        Color.clear.frame(height: diHeight)

                        if expanded {
                            SignalFieldRadarView(
                                state: currentState,
                                latencyMs: mockLatency
                            )
                            .frame(height: contentHeight)
                            .transition(.opacity)
                        }
                    }
                    .frame(width: currentW)
                    .background(
                        RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                            .fill(Color.black)
                            .shadow(color: .black.opacity(expanded ? 0.6 : 0), radius: 24, y: 12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: currentCorner, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                            .strokeBorder(
                                currentState.color.opacity(expanded ? 0.12 : 0),
                                lineWidth: 0.5
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .offset(y: diTopY)
                }
                .frame(height: diTopY + diHeight + (expanded ? contentHeight : 0) + 30)
                .ignoresSafeArea(edges: .top)

                Spacer()

                // Controls
                VStack(spacing: 16) {
                    Text("GATEWAY STATUS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.25))

                    // State switcher
                    HStack(spacing: 12) {
                        ForEach(GatewayConnectionState.allCases) { st in
                            stateButton(st)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                                expanded.toggle()
                            }
                        } label: {
                            Text(expanded ? "Collapse" : "Expand")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.08), in: Capsule())
                        }

                        Button {
                            autoCycleStates()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Cycle")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.04), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
    }

    @ViewBuilder
    private func stateButton(_ st: GatewayConnectionState) -> some View {
        let selected = currentState == st
        Button {
            currentState = st
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(st.color.opacity(selected ? 1.0 : 0.25))
                    .frame(width: 10, height: 10)

                Text(st.label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(selected ? st.color : .white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(st.color.opacity(selected ? 0.07 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(st.color.opacity(selected ? 0.18 : 0), lineWidth: 0.5)
            )
        }
    }

    private func autoCycleStates() {
        let states: [GatewayConnectionState] = [.reconnecting, .connected, .reconnecting, .connected]
        for (i, st) in states.enumerated() {
            Task {
                try? await Task.sleep(for: .seconds(Double(i) * 3.0))
                await MainActor.run {
                    currentState = st
                }
            }
        }
    }
}

#Preview {
    GatewayStatusMockView()
        .preferredColorScheme(.dark)
}
