import SwiftUI

/// Boring Avatars "Beam" variant — deterministic face avatars from any string.
/// Port of https://github.com/boringdesigners/boring-avatars (MIT license).
struct BeamAvatar: View {
    let name: String
    let size: CGFloat
    var palette: [Color]? = nil

    // All available palettes
    static let allPalettes: [[Color]] = [
        defaultPalette, ocean, sunset, neon, earth, berry, forest, candy, arctic, lava,
    ]

    static let defaultPalette: [Color] = [
        Color(hex: "FF6B35"), Color(hex: "7C5CFC"), Color(hex: "00C9A7"),
        Color(hex: "FFB800"), Color(hex: "FF4081"),
    ]
    static let ocean: [Color] = [
        Color(hex: "0077B6"), Color(hex: "00B4D8"), Color(hex: "90E0EF"),
        Color(hex: "CAF0F8"), Color(hex: "023E8A"),
    ]
    static let sunset: [Color] = [
        Color(hex: "FF6B6B"), Color(hex: "FFA06B"), Color(hex: "FFD93D"),
        Color(hex: "6BCB77"), Color(hex: "4D96FF"),
    ]
    static let neon: [Color] = [
        Color(hex: "FF00FF"), Color(hex: "00FFFF"), Color(hex: "FFFF00"),
        Color(hex: "FF3366"), Color(hex: "33FF99"),
    ]
    static let earth: [Color] = [
        Color(hex: "8B5E3C"), Color(hex: "D4A574"), Color(hex: "2D5016"),
        Color(hex: "C7956D"), Color(hex: "5C4033"),
    ]
    static let berry: [Color] = [
        Color(hex: "6A0572"), Color(hex: "AB83A1"), Color(hex: "E36BAE"),
        Color(hex: "F15BB5"), Color(hex: "9B5DE5"),
    ]
    static let forest: [Color] = [
        Color(hex: "1B4332"), Color(hex: "2D6A4F"), Color(hex: "52B788"),
        Color(hex: "95D5B2"), Color(hex: "D8F3DC"),
    ]
    static let candy: [Color] = [
        Color(hex: "F72585"), Color(hex: "B5179E"), Color(hex: "7209B7"),
        Color(hex: "560BAD"), Color(hex: "480CA8"),
    ]
    static let arctic: [Color] = [
        Color(hex: "A2D2FF"), Color(hex: "BDE0FE"), Color(hex: "FFAFCC"),
        Color(hex: "FFC8DD"), Color(hex: "CDB4DB"),
    ]
    static let lava: [Color] = [
        Color(hex: "D00000"), Color(hex: "E85D04"), Color(hex: "FAA307"),
        Color(hex: "FFBA08"), Color(hex: "DC2F02"),
    ]

    /// Picks a palette deterministically from the name hash
    private var resolvedPalette: [Color] {
        if let palette { return palette }
        let h = hashCode(name + "pal")
        return Self.allPalettes[Int(h) % Self.allPalettes.count]
    }

    var body: some View {
        let data = generateData(name: name, colors: resolvedPalette)
        let scale = size / 36.0

        Canvas { ctx, canvasSize in
            // Clip to circle
            let bounds = CGRect(origin: .zero, size: canvasSize)
            ctx.clip(to: Path(ellipseIn: bounds))

            // Background
            ctx.fill(Path(bounds), with: .color(data.backgroundColor))

            // Wrapper shape (colored blob)
            ctx.drawLayer { wrapper in
                let center = CGPoint(x: 18 * scale, y: 18 * scale)
                wrapper.translateBy(x: data.wrapperTranslateX * scale, y: data.wrapperTranslateY * scale)
                // Rotate around center: translate to center, rotate, translate back
                wrapper.translateBy(x: center.x, y: center.y)
                wrapper.rotate(by: Angle.degrees(data.wrapperRotate))
                wrapper.translateBy(x: -center.x, y: -center.y)
                // Scale from center
                let s = data.wrapperScale
                wrapper.translateBy(x: center.x * (1 - s), y: center.y * (1 - s))
                wrapper.scaleBy(x: s, y: s)

                let wrapperRect = CGRect(x: 0, y: 0, width: 36 * scale, height: 36 * scale)
                let rx = data.isCircle ? 36 * scale : 6 * scale
                let wrapperPath = Path(roundedRect: wrapperRect, cornerRadius: rx)
                wrapper.fill(wrapperPath, with: .color(data.wrapperColor))
            }

            // Face group
            ctx.drawLayer { face in
                let center = CGPoint(x: 18 * scale, y: 18 * scale)
                face.translateBy(x: data.faceTranslateX * scale, y: data.faceTranslateY * scale)
                face.translateBy(x: center.x, y: center.y)
                face.rotate(by: Angle.degrees(data.faceRotate))
                face.translateBy(x: -center.x, y: -center.y)

                let faceColor = data.faceColor

                // Left eye
                let leftEyeRect = CGRect(
                    x: (14 - data.eyeSpread) * scale,
                    y: 14 * scale,
                    width: 1.5 * scale,
                    height: 2 * scale
                )
                face.fill(Path(roundedRect: leftEyeRect, cornerRadius: 1 * scale), with: .color(faceColor))

                // Right eye
                let rightEyeRect = CGRect(
                    x: (20 + data.eyeSpread) * scale,
                    y: 14 * scale,
                    width: 1.5 * scale,
                    height: 2 * scale
                )
                face.fill(Path(roundedRect: rightEyeRect, cornerRadius: 1 * scale), with: .color(faceColor))

                // Mouth
                let mouthY = (19 + data.mouthSpread) * scale
                if data.isMouthOpen {
                    // Smile line: cubic bezier
                    var mouth = Path()
                    mouth.move(to: CGPoint(x: 15 * scale, y: mouthY))
                    mouth.addCurve(
                        to: CGPoint(x: 21 * scale, y: mouthY),
                        control1: CGPoint(x: 17 * scale, y: mouthY + 1 * scale),
                        control2: CGPoint(x: 19 * scale, y: mouthY + 1 * scale)
                    )
                    face.stroke(mouth, with: .color(faceColor), style: StrokeStyle(lineWidth: 1 * scale, lineCap: .round))
                } else {
                    // Open mouth: arc (half ellipse)
                    var mouth = Path()
                    mouth.move(to: CGPoint(x: 13 * scale, y: mouthY))
                    mouth.addRelativeArc(
                        center: CGPoint(x: 18 * scale, y: mouthY),
                        radius: 5 * scale,
                        startAngle: .degrees(180),
                        delta: .degrees(-180)
                    )
                    face.fill(mouth, with: .color(faceColor))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Data Generation

private struct BeamData {
    let wrapperColor: Color
    let backgroundColor: Color
    let faceColor: Color
    let wrapperTranslateX: CGFloat
    let wrapperTranslateY: CGFloat
    let wrapperRotate: Double
    let wrapperScale: CGFloat
    let isCircle: Bool
    let isMouthOpen: Bool
    let eyeSpread: CGFloat
    let mouthSpread: CGFloat
    let faceTranslateX: CGFloat
    let faceTranslateY: CGFloat
    let faceRotate: Double
}

private func generateData(name: String, colors: [Color]) -> BeamData {
    // Use multiple independent hashes to avoid parameter correlation
    let h0 = hashCode(name)
    let h1 = hashCode(name + "bg")
    let h2 = hashCode(name + "wr")
    let h3 = hashCode(name + "fc")
    let h4 = hashCode(name + "ey")
    let h5 = hashCode(name + "mo")

    let range = colors.count

    // Pick colors from different hashes so bg != wrapper more often
    let wrapperColor = colors[Int(h0) % range]
    let bgIndex = (Int(h1) % (range - 1) + 1 + Int(h0) % range) % range
    let backgroundColor = colors[bgIndex]
    let faceColor = contrastColor(for: wrapperColor)

    let preTranslateX = getUnit(h2, range: 10, index: 0)
    let wrapperTranslateX = preTranslateX < 5 ? preTranslateX + 4.0 : preTranslateX

    let preTranslateY = getUnit(h2, range: 10, index: 3)
    let wrapperTranslateY = preTranslateY < 5 ? preTranslateY + 4.0 : preTranslateY

    let wrapperRotate = Double(h2 % 360)
    let wrapperScale = 1.0 + CGFloat(h2 % 5) / 12.0

    let isMouthOpen = h5 % 2 == 0
    let isCircle = h3 % 2 == 0
    let eyeSpread = CGFloat(h4 % 7)
    let mouthSpread = CGFloat(h5 % 5)
    let faceRotate = Double(getUnit(h3, range: 14, index: 1))

    let faceTranslateX = wrapperTranslateX > 6
        ? wrapperTranslateX / 2.0
        : CGFloat(getUnit(h3, range: 8, index: 2))
    let faceTranslateY = wrapperTranslateY > 6
        ? wrapperTranslateY / 2.0
        : CGFloat(getUnit(h3, range: 7, index: 4))

    return BeamData(
        wrapperColor: wrapperColor,
        backgroundColor: backgroundColor,
        faceColor: faceColor,
        wrapperTranslateX: CGFloat(wrapperTranslateX),
        wrapperTranslateY: CGFloat(wrapperTranslateY),
        wrapperRotate: wrapperRotate,
        wrapperScale: wrapperScale,
        isCircle: isCircle,
        isMouthOpen: isMouthOpen,
        eyeSpread: eyeSpread,
        mouthSpread: mouthSpread,
        faceTranslateX: CGFloat(faceTranslateX),
        faceTranslateY: CGFloat(faceTranslateY),
        faceRotate: faceRotate
    )
}

// MARK: - Hash Utilities

/// Java-style hashCode, matching the JS implementation.
private func hashCode(_ str: String) -> UInt32 {
    var hash: Int32 = 0
    for char in str.unicodeScalars {
        hash = ((hash &<< 5) &- hash) &+ Int32(char.value)
    }
    return UInt32(bitPattern: hash < 0 ? -hash : hash)
}

private func getDigit(_ number: UInt32, position: Int) -> UInt32 {
    let divisor = UInt32(pow(10.0, Double(position)))
    return (number / divisor) % 10
}

private func getBoolean(_ number: UInt32, position: Int) -> Bool {
    getDigit(number, position: position) % 2 == 0
}

/// Returns a value in -(range-1)..+(range-1) when index is provided.
private func getUnit(_ number: UInt32, range: Int, index: Int) -> Double {
    let value = Double(number % UInt32(range))
    return getDigit(number, position: index) % 2 == 0 ? -value : value
}

// MARK: - Color Contrast

/// Returns black or white based on YIQ luminance of the input color.
private func contrastColor(for color: Color) -> Color {
    // Resolve to RGB components
    let uiColor = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    let yiq = (r * 299 + g * 587 + b * 114) / 1000
    return yiq >= 0.5 ? .black : .white
}

// MARK: - Previews

#Preview("Gallery") {
    let names = [
        "openclaw-1", "agent-alpha", "cron-bot", "deploy-agent",
        "refactor-guru", "test-runner", "monitor-v2", "debug-helper",
        "weekly-report", "api-gateway", "data-sync", "log-analyzer",
    ]

    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
            ForEach(names, id: \.self) { name in
                VStack(spacing: 6) {
                    BeamAvatar(name: name, size: 64)
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}

#Preview("Sizes") {
    HStack(spacing: 16) {
        BeamAvatar(name: "test", size: 24)
        BeamAvatar(name: "test", size: 36)
        BeamAvatar(name: "test", size: 48)
        BeamAvatar(name: "test", size: 64)
    }
    .padding()
    .background(Color.black)
}
