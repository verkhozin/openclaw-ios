import SwiftUI

/// Custom folder front panel shape.
///
/// ```
///  ╭──────────────╮
///  │               ╲______╮
///  │                      │
///  ╰──────────────────────╯
/// ```
///
/// Proportions: ~2 parts tab, ~1 part slope, ~1 part shelf.
/// Inner corners at the step are concave (quadratic bezier curves).
struct FolderFrontShape: Shape {
    /// Height difference between left and right as a fraction of total height
    var stepRatio: CGFloat = 0.20
    /// Where the slope starts (fraction of width)
    var slopeStart: CGFloat = 0.55
    /// Where the slope ends (fraction of width)
    var slopeEnd: CGFloat = 0.65
    /// Outer corner radius as fraction of the shorter dimension
    var cornerRadiusRatio: CGFloat = 0.12
    /// Concave corner radius as fraction of the shorter dimension
    var innerRadiusRatio: CGFloat = 0.09

    func path(in rect: CGRect) -> Path {
        var p = Path()

        let w = rect.width
        let h = rect.height
        let base = min(w, h)

        let cr = base * cornerRadiusRatio
        let ir = base * innerRadiusRatio

        // Y levels
        let yBottom = h
        let yTop: CGFloat = 0
        let yShelf = h * stepRatio

        // X positions for the slope
        let xSlopeStart = w * slopeStart
        let xSlopeEnd = w * slopeEnd

        // Slope angle for offsetting the inner curve points
        let slopeW = xSlopeEnd - xSlopeStart
        let slopeH = yShelf - yTop
        let slopeLen = hypot(slopeW, slopeH)
        let dx = slopeW / slopeLen * ir  // unit vector along slope * ir
        let dy = slopeH / slopeLen * ir

        // --- Bottom-left corner ---
        p.move(to: CGPoint(x: 0, y: yBottom - cr))
        p.addArc(
            tangent1End: CGPoint(x: 0, y: yBottom),
            tangent2End: CGPoint(x: cr, y: yBottom),
            radius: cr
        )

        // --- Bottom edge → bottom-right corner ---
        p.addLine(to: CGPoint(x: w - cr, y: yBottom))
        p.addArc(
            tangent1End: CGPoint(x: w, y: yBottom),
            tangent2End: CGPoint(x: w, y: yBottom - cr),
            radius: cr
        )

        // --- Right edge → top-right corner ---
        p.addLine(to: CGPoint(x: w, y: yShelf + cr))
        p.addArc(
            tangent1End: CGPoint(x: w, y: yShelf),
            tangent2End: CGPoint(x: w - cr, y: yShelf),
            radius: cr
        )

        // --- Shelf top → concave corner into slope ---
        // Stop ir before the corner, quad curve through the corner point
        p.addLine(to: CGPoint(x: xSlopeEnd + ir, y: yShelf))
        p.addQuadCurve(
            to: CGPoint(x: xSlopeEnd - dx, y: yShelf - dy),
            control: CGPoint(x: xSlopeEnd, y: yShelf)
        )

        // --- Slope → concave corner into top edge ---
        // Go up the slope, stop ir before the top corner
        p.addLine(to: CGPoint(x: xSlopeStart + dx, y: yTop + dy))
        p.addQuadCurve(
            to: CGPoint(x: xSlopeStart - ir, y: yTop),
            control: CGPoint(x: xSlopeStart, y: yTop)
        )

        // --- Top edge → top-left corner ---
        p.addLine(to: CGPoint(x: cr, y: yTop))
        p.addArc(
            tangent1End: CGPoint(x: 0, y: yTop),
            tangent2End: CGPoint(x: 0, y: yTop + cr),
            radius: cr
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - Folder View

struct FolderView: View {
    var color: Color = Color(hex: "3A3A3C")
    var documentColor: Color = Color(hex: "E8E8ED")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cr = min(w, h) * 0.12

            ZStack(alignment: .bottom) {
                // Back panel
                RoundedRectangle(cornerRadius: cr)
                    .fill(color.opacity(0.5))
                    .frame(width: w, height: h * 0.95)

                // Documents peeking out
                documents(w: w, h: h)
                    .offset(y: -h * 0.14)

                // Front panel — liquid glass
                if #available(iOS 26, *) {
                    FolderFrontShape()
                        .fill(color.opacity(0.05))
                        .glassEffect(.regular.tint(color), in: FolderFrontShape())
                        .opacity(0.7)
                        .frame(width: w, height: h * 0.85)
                } else {
                    FolderFrontShape()
                        .fill(color.opacity(0.75))
                        .overlay(
                            FolderFrontShape()
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .frame(width: w, height: h * 0.85)
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(1.2, contentMode: .fit)
    }

    private func documents(w: CGFloat, h: CGFloat) -> some View {
        let docW = w * 0.50
        let docH = h * 0.8

        return ZStack {
            // Right (bottom of stack, lowest)
            documentSheet(width: docW, height: docH)
                .rotationEffect(.degrees(8), anchor: .bottom)
                .offset(x: docW * 0.2, y: docH * 0.06)

            // Center (middle height)
            documentSheet(width: docW, height: docH)
                .rotationEffect(.degrees(3), anchor: .bottom)

            // Left (top of stack, highest)
            documentSheet(width: docW, height: docH)
                .rotationEffect(.degrees(-4), anchor: .bottom)
                .offset(x: -docW * 0.3, y: -docH * 0.06)
        }
    }

    private func documentSheet(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.06)
                .fill(documentColor)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)

            VStack(alignment: .leading, spacing: height * 0.07) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(
                            width: width * (i == 4 ? 0.45 : 0.7),
                            height: height * 0.05
                        )
                }
            }
            .offset(y: -height * 0.13)
        }
    }
}

// MARK: - Preview

#Preview("Folder") {
    VStack(spacing: 32) {
        FolderView()
            .frame(width: 260)
        FolderView(color: Theme.accent)
            .frame(width: 160)
        FolderView(color: Color(hex: "007AFF"))
            .frame(width: 100)
    }
    .padding(40)
    .background(Color(hex: "F2F2F7"))
}

#Preview("Shape Only") {
    FolderFrontShape()
        .stroke(Color.white, lineWidth: 2)
        .frame(width: 260, height: 140)
        .padding(40)
        .background(Color.black)
}
