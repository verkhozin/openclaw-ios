import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var auroraExpanded = false
    @State private var shaderVisible = false
    @State private var showExpandedContent = false
    @State private var dashboardVisible = true

    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 0: Shader
                MetalShaderView(fps: auroraExpanded ? 60 : 30, shader: .sky, isVisible: $shaderVisible)
                    .ignoresSafeArea()

                // Layer 1: Animated mask
                DashboardMask(expanded: auroraExpanded)

                // Layer 2: Dashboard content
                ScrollView {
                    VStack(spacing: Theme.paddingM) {
                        Color.clear
                            .aspectRatio(2.5 / 1, contentMode: .fit)
                            .overlay {
                                VStack(spacing: 6) {
                                    Text(greeting)
                                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(timeString)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .opacity(dashboardVisible ? 1 : 0)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .onTapGesture { expand() }

                        UsageCard(
                            sessionPercent: gateway.status.sessionPercent,
                            weeklyPercent: gateway.status.weeklyPercent
                        )

                        QuickActionsGrid()

                        let activeTasks = gateway.tasks.filter { $0.status == .running }
                        if !activeTasks.isEmpty {
                            ActiveTasksCard(tasks: activeTasks)
                        }
                    }
                    .padding(Theme.paddingM)
                }
                .opacity(dashboardVisible ? 1 : 0)
                .allowsHitTesting(dashboardVisible)
                .navigationTitle("Dashboard")

                // Layer 3: Expanded overlay
                if auroraExpanded {
                    AuroraExpandedOverlay(
                        isExpanded: $auroraExpanded,
                        showContent: $showExpandedContent,
                        gateway: gateway
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear { shaderVisible = true }
        .onDisappear { shaderVisible = false }
        .onChange(of: auroraExpanded) { _, isExpanded in
            if !isExpanded {
                // Closing — dashboard appears AFTER mask finishes (3s H)
                withAnimation(.easeOut(duration: 0.4).delay(3.0)) {
                    dashboardVisible = true
                }
            }
        }
    }

    private func expand() {
        withAnimation(.easeOut(duration: 0.3)) {
            dashboardVisible = false
        }
        auroraExpanded = true
        showExpandedContent = true
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }
}

// MARK: - Animated Mask

struct DashboardMask: View {
    var expanded: Bool
    @State private var progressH: CGFloat = 0
    @State private var progressV: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width
            let screenH = geo.size.height
            let cardW = screenW - Theme.paddingM * 2
            let cardH = cardW / 2.5
            let cardX = Theme.paddingM + cardW / 2
            let cardY = Theme.paddingM + cardH / 2

            let holeW = cardW + (screenW * 2 - cardW) * progressH
            let holeH = cardH + (screenH * 2 - cardH) * progressV
            let holeX = cardX + (screenW / 2 - cardX) * progressH
            let holeY = cardY + (screenH / 2 - cardY) * progressV
            let holeR: CGFloat = 24 * (1 - progressH)

            Theme.bg
                .ignoresSafeArea()
                .mask {
                    Rectangle()
                        .ignoresSafeArea()
                        .overlay {
                            RoundedRectangle(cornerRadius: holeR, style: .continuous)
                                .frame(width: holeW, height: holeH)
                                .position(x: holeX, y: holeY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .allowsHitTesting(false)
        }
        .onChange(of: expanded) { _, isExpanded in
            if isExpanded {
                // Open: vertical fast, horizontal slow
                withAnimation(.easeInOut(duration: 1.2)) {
                    progressV = 1
                }
                withAnimation(.easeInOut(duration: 3.0)) {
                    progressH = 1
                }
            } else {
                // Close: reverse — horizontal fast first, vertical slow after
                withAnimation(.easeInOut(duration: 1.2)) {
                    progressH = 0
                }
                withAnimation(.easeInOut(duration: 3.0)) {
                    progressV = 0
                }
            }
        }
    }
}
