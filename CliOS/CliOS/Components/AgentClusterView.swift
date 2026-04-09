import SwiftUI

// MARK: - Agent Cluster View
//
// "Workflow started" — split layout.
// Left: label. Right: mini 3→1→2 DAG, accent-colored rect nodes.

struct AgentClusterView: View {
    var workflowName: String = "lead-gen"
    var agentCount: Int = 6

    @State private var nodeVisible = Array(repeating: false, count: 6)
    @State private var edgeTrim = Array(repeating: CGFloat(0), count: 5)
    @State private var breathe: CGFloat = 0
    @State private var labelOpacity: CGFloat = 0
    @State private var labelSlide: CGFloat = 6

    private let nodeW: CGFloat = 34
    private let nodeH: CGFloat = 14
    private let nodeCorner: CGFloat = 4
    private let rowGap: CGFloat = 20
    private let accent = Color(hex: "FF4D00")

    // Fixed 3 → 1 → 2 DAG
    //   [0] \         / [4]
    //   [1] — [3] —
    //   [2] /         \ [5]
    private static let gNodes: [(col: Int, row: Int)] = [
        (0, -1), (0, 0), (0, 1),   // left: 3
        (1, 0),                     // hub: 1
        (2, -1), (2, 1),            // right: 2
    ]
    private static let gEdges: [(from: Int, to: Int)] = [
        (0, 3), (1, 3), (2, 3),    // 3 → hub
        (3, 4), (3, 5),            // hub → 2
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2
            let graphL = w * 0.54
            let colStep = ((w - 16) - graphL - nodeW) / 2

            // --- Label (left) ---
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 3, height: 14)
                    Text("Workflow started")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                Text("\(agentCount) agents · \(workflowName)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.leading, 24)
            .frame(maxHeight: .infinity, alignment: .center)
            .opacity(labelOpacity)
            .offset(y: labelSlide)

            // --- Edges ---
            ForEach(Array(Self.gEdges.enumerated()), id: \.offset) { idx, edge in
                let from = Self.gNodes[edge.from]
                let to   = Self.gNodes[edge.to]
                let x0 = graphL + CGFloat(from.col) * colStep + nodeW / 2
                let y0 = midY + CGFloat(from.row) * rowGap
                let x1 = graphL + CGFloat(to.col) * colStep - nodeW / 2
                let y1 = midY + CGFloat(to.row) * rowGap

                NodeConnector(x0: x0, y0: y0, x1: x1, y1: y1)
                    .trim(from: 0, to: idx < edgeTrim.count ? edgeTrim[idx] : 0)
                    .stroke(accent.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // --- Nodes ---
            ForEach(0..<Self.gNodes.count, id: \.self) { i in
                let node = Self.gNodes[i]
                let x = graphL + CGFloat(node.col) * colStep
                let y = midY + CGFloat(node.row) * rowGap

                nodeRect()
                    .scaleEffect(i < nodeVisible.count && nodeVisible[i] ? 1 : 0.01)
                    .opacity(i < nodeVisible.count && nodeVisible[i] ? 1 : 0)
                    .position(x: x, y: y)
            }

            // --- Top fade ---
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.2), location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 14)
            .allowsHitTesting(false)
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Node

    @ViewBuilder
    private func nodeRect() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: nodeCorner + 2)
                .fill(accent.opacity(0.10 + breathe * 0.08))
                .frame(width: nodeW + 12, height: nodeH + 12)
                .blur(radius: 5)

            RoundedRectangle(cornerRadius: nodeCorner)
                .fill(Color.black)
                .frame(width: nodeW, height: nodeH)

            RoundedRectangle(cornerRadius: nodeCorner)
                .strokeBorder(accent.opacity(0.60 + breathe * 0.22), lineWidth: 1.5)
                .frame(width: nodeW, height: nodeH)
        }
    }

    // MARK: - Entrance

    private func runEntrance() {
        // Nodes cascade by column: 0 → 1 → 2
        for (i, node) in Self.gNodes.enumerated() {
            let delay = Double(node.col) * 0.22
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                    if i < nodeVisible.count { nodeVisible[i] = true }
                }
            }
        }

        // Edges draw after their source column's nodes
        for (idx, edge) in Self.gEdges.enumerated() {
            let fromCol = Self.gNodes[edge.from].col
            let delay = Double(fromCol) * 0.22 + 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.22)) {
                    if idx < edgeTrim.count { edgeTrim[idx] = 1 }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                breathe = 1
            }
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            labelOpacity = 1
            labelSlide = 0
        }
    }
}

// MARK: - Connector (S-curve for diagonal, straight for same-Y)

private struct NodeConnector: Shape {
    var x0, y0, x1, y1: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        if y0 == y1 {
            p.addLine(to: CGPoint(x: x1, y: y1))
        } else {
            let midX = (x0 + x1) / 2
            p.addCurve(
                to: CGPoint(x: x1, y: y1),
                control1: CGPoint(x: midX, y: y0),
                control2: CGPoint(x: midX, y: y1)
            )
        }
        return p
    }
}
