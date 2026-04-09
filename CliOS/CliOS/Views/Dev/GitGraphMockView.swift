import SwiftUI

/// Dev view to preview git activity graph inside a Dynamic Island expansion frame.
struct GitGraphMockView: View {
    @State private var currentEvent: GitEvent = .threeCommits
    @State private var expanded = true
    @State private var refreshID = UUID()

    // DI geometry (matches IslandCalibrationView)
    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8
    private let expandedHPad: CGFloat = 11.3
    private let expandedCorner: CGFloat = 49.1
    private let contentHeight: CGFloat = 130

    private var accentColor: Color {
        switch currentEvent.type {
        case .branchCreated: return Color(hex: "A78BFA")
        case .commitPushed: return Color(hex: "34C759")
        case .deployTriggered: return Color(hex: "60A5FA")
        }
    }

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
                            GitGraphView(event: currentEvent)
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
                            .strokeBorder(
                                accentColor.opacity(expanded ? 0.12 : 0),
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
                    Text("GIT ACTIVITY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.25))

                    // Event type switcher
                    HStack(spacing: 8) {
                        eventButton("Branch", icon: "arrow.triangle.branch",
                                    color: Color(hex: "A78BFA"), event: .branchCreated)
                        eventButton("1 commit", icon: "circle",
                                    color: Color(hex: "34C759"), event: .oneCommit)
                        eventButton("3 commits", icon: "circle.grid.3x1",
                                    color: Color(hex: "34C759"), event: .threeCommits)
                        eventButton("12 commits", icon: "circle.grid.3x3",
                                    color: Color(hex: "34C759"), event: .twelveCommits)
                        eventButton("Deploy", icon: "paperplane.fill",
                                    color: Color(hex: "60A5FA"), event: .deploy)
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
                            refreshID = UUID()
                        } label: {
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

    @ViewBuilder
    private func eventButton(_ title: String, icon: String,
                             color: Color, event: GitEvent) -> some View {
        let selected = currentEvent.type == event.type && currentEvent.commitCount == event.commitCount
        Button {
            currentEvent = event
            refreshID = UUID()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? color : .white.opacity(0.25))

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(selected ? color : .white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(selected ? 0.07 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(selected ? 0.18 : 0), lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    GitGraphMockView()
        .preferredColorScheme(.dark)
}
