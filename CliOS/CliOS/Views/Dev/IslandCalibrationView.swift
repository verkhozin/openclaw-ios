import SwiftUI

/// Dev screen to visually calibrate the Island notification expansion.
struct IslandCalibrationView: View {
    // Calibrated DI values
    private let diTopY: CGFloat = 14
    private let diHeight: CGFloat = 36.7
    private let diWidth: CGFloat = 124.8

    // Tunable expansion params
    @State private var expandedHPad: CGFloat = 6
    @State private var expandedCorner: CGFloat = 38
    @State private var contentHeight: CGFloat = 80

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                let screenW = geo.size.width
                let expandedW = screenW - expandedHPad * 2
                let currentW = appeared ? expandedW : diWidth
                let currentCorner = appeared ? expandedCorner : diHeight / 2

                VStack(spacing: 0) {
                    // DI zone
                    Color.clear.frame(height: diHeight)

                    // Content zone
                    if appeared {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.clear)
                            .frame(height: contentHeight)
                            .overlay {
                                Text("Content area")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                    }
                }
                .frame(width: currentW)
                .background {
                    RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                        .fill(Color(white: 0.08))
                        .shadow(color: .black.opacity(appeared ? 0.5 : 0), radius: 20, y: 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: currentCorner, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: currentCorner, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .offset(y: diTopY)
            }
            .ignoresSafeArea(edges: .top)

            // Controls
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text("Island Expansion")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    sliderRow("Pad", value: $expandedHPad, range: 0...40)
                    sliderRow("Corner", value: $expandedCorner, range: 10...55)
                    sliderRow("Height", value: $contentHeight, range: 40...200)

                    Text("pad: \(String(format: "%.1f", expandedHPad))  corner: \(String(format: "%.1f", expandedCorner))  h: \(String(format: "%.1f", contentHeight))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))

                    Button(appeared ? "Collapse" : "Expand") {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                            appeared.toggle()
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
                }
                .padding(20)
                .background(Color.black.opacity(0.85))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.red)

            Text(String(format: "%.1f", value.wrappedValue))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
}

#Preview {
    IslandCalibrationView()
}
