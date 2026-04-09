import SwiftUI

struct AgentClusterMockView: View {
    @State private var refreshID = UUID()
    @State private var expanded = true

    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let contentHeight: CGFloat = 120

    private let accent = Color(hex: "FF4D00")

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
                            AgentClusterView(
                                workflowName: "lead-gen",
                                agentCount: 6
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
                .padding(.bottom, 50)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
    }
}

#Preview {
    AgentClusterMockView()
        .preferredColorScheme(.dark)
}
