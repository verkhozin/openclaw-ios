import Foundation

enum ShaderType: String, CaseIterable, Identifiable {
    case coastal = "Coastal"
    case warpFBM = "Warp"
    case asciiWave = "ASCII"
    case sunsetClouds = "Sunset"
    case sky = "Sky"
    case plasma = "Plasma"
    case flare = "Flare"
    case vectorField = "Field"
    case asciiPlasma = "ASCII Plasma"
    case morningSky = "Morning"
    case eveningSky = "Evening"
    case nightSky = "Night"
    case rain = "Rain"

    var id: String { rawValue }

    var fragmentFunction: String {
        switch self {
        case .coastal: return "coastalFragment"
        case .warpFBM: return "warpFBMFragment"
        case .asciiWave: return "asciiWaveFragment"
        case .sunsetClouds: return "sunsetCloudsFragment"
        case .sky: return "skyFragment"
        case .plasma: return "plasmaFragment"
        case .flare: return "flareFragment"
        case .vectorField: return "vectorFieldFragment"
        case .asciiPlasma: return "asciiPlasmaFragment"
        case .morningSky: return "morningSkyFragment"
        case .eveningSky: return "eveningSkyFragment"
        case .nightSky: return "nightSkyFragment"
        case .rain: return "rainFragment"
        }
    }
}
