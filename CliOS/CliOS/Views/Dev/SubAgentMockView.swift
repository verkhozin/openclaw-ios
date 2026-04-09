import SwiftUI

struct SubAgentMockView: View {
    @State private var refreshID = UUID()
    @State private var expanded = true
    @State private var scenarioIndex = 0

    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let contentHeight: CGFloat = 120

    private let accent = Color(hex: "FF4D00")

    private let scenarios: [(label: String, status: SubAgentView.Status, task: String)] = [
        (
            "Searching",
            .running,
            "Researching company background and extracting key decision makers"
        ),
        (
            "Browsing",
            .running,
            "Browsing product page and extracting pricing and feature information"
        ),
        (
            "Writing",
            .running,
            "Drafting personalized outreach email based on company profile"
        ),
        (
            "Done",
            .done,
            "Qualified 3 leads — Stripe, Vercel, Linear — confidence 87%, 74%, 91%"
        ),
    ]

    private var current: (label: String, status: SubAgentView.Status, task: String) {
        scenarios[scenarioIndex]
    }

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { geo in
                    let expandedW = geo.size.width - expandedHPad * 2
                    let currentW = expanded ? expandedW : diWidth
                    let currentCorner = expanded ? expandedCorner : diHeight / 2

                    VStack(spacing: 0) {
                        Color.clear.frame(height: diHeight)

                        if expanded {
                            SubAgentView(
                                taskText: current.task,
                                status: current.status
                            )
                            .id(refreshID)
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
                            .strokeBorder(accent.opacity(expanded ? 0.12 : 0), lineWidth: 0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .offset(y: diTopY)
                }
                .frame(height: diTopY + diHeight + (expanded ? contentHeight : 0) + 30)
                .ignoresSafeArea(edges: .top)

                Spacer()

                VStack(spacing: 16) {
                    Text("SUB-AGENT SPAWNED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.25))

                    HStack(spacing: 8) {
                        ForEach(Array(scenarios.enumerated()), id: \.offset) { i, s in
                            Button {
                                scenarioIndex = i
                                refreshID = UUID()
                            } label: {
                                Text(s.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(scenarioIndex == i ? .white : .white.opacity(0.3))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(
                                        scenarioIndex == i ? accent.opacity(0.12) : .white.opacity(0.04)
                                    ))
                                    .overlay(Capsule().strokeBorder(
                                        scenarioIndex == i ? accent.opacity(0.3) : .clear,
                                        lineWidth: 0.5
                                    ))
                            }
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

                        Button { refreshID = UUID() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Replay")
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
}

#Preview {
    SubAgentMockView()
        .preferredColorScheme(.dark)
}
