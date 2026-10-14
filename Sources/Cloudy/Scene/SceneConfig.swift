import SwiftUI

enum CloudTone: Int, CaseIterable {
    case bright, gray, dark, storm
    case night, nightGray, nightDark, nightStorm

    var atNight: CloudTone {
        switch self {
        case .bright: .night
        case .gray: .nightGray
        case .dark: .nightDark
        case .storm: .nightStorm
        default: self
        }
    }

    /// (top highlight, bottom shadow) of a cloud body.
    var colors: (top: UInt32, bottom: UInt32) {
        switch self {
        case .bright: (0xF2F5FA, 0xA4B0C2)
        case .gray: (0xA3AEBD, 0x5C6777)
        case .dark: (0x6A7483, 0x313946)
        case .storm: (0x434B58, 0x161A22)
        case .night: (0x4D5B76, 0x1A2437)
        case .nightGray: (0x343E50, 0x151C28)
        case .nightDark: (0x262E3B, 0x0F141C)
        case .nightStorm: (0x1D232D, 0x090C11)
        }
    }
}

enum RainStyle { case drizzle, rain, heavy }

/// Everything the renderer needs to paint one sky. Intensities are 0…1.
struct SceneConfig: Equatable {
    var kind: WeatherKind
    var isDay: Bool
    var sky: [UInt32] = []

    var cloudCover = 0.0
    var cloudTone = CloudTone.bright
    var cloudSpeed = 1.0
    var deck = 0.0            // overcast ceiling darkening the top of the sky

    var stars = 0.0
    var milkyWay = false
    var celestial = 0.0       // sun / moon visibility
    var motes = 0.0           // golden dust drifting through sunlight

    var rain = 0.0
    var rainStyle = RainStyle.rain
    var ice = 0.0             // sleet pellets
    var snow = 0.0
    var blizzard = false
    var hail = 0.0
    var lightning = 0.0
    var fog = 0.0
    var frost = 0.0
    var wind = 0.1
    var windStreaks = 0.0
    var leaves = 0.0

    var identity: String { "\(kind.rawValue)-\(isDay)" }

    static func make(kind: WeatherKind, isDay: Bool, windKmh: Double?) -> SceneConfig {
        var c = SceneConfig(kind: kind, isDay: isDay)
        switch kind {
        case .clear:
            c.cloudCover = 0.06; c.stars = 1; c.celestial = 1; c.motes = 1; c.milkyWay = true
        case .mostlyClear:
            c.cloudCover = 0.28; c.stars = 0.8; c.celestial = 1; c.motes = 0.5
        case .partlyCloudy:
            c.cloudCover = 0.55; c.stars = 0.45; c.celestial = 0.85
        case .overcast:
            c.cloudCover = 1; c.cloudTone = .gray; c.deck = 0.75; c.celestial = 0.08
        case .fog:
            c.cloudCover = 0.35; c.cloudTone = .gray; c.fog = 1; c.celestial = 0.3; c.cloudSpeed = 0.5
        case .windy:
            c.cloudCover = 0.5; c.windStreaks = 1; c.leaves = 1; c.wind = 0.9
            c.cloudSpeed = 2.4; c.celestial = 0.7; c.stars = 0.4
        case .drizzle:
            c.cloudCover = 0.9; c.cloudTone = .gray; c.deck = 0.55
            c.rain = 0.6; c.rainStyle = .drizzle; c.fog = 0.25
        case .rain:
            c.cloudCover = 1; c.cloudTone = .dark; c.deck = 0.8; c.rain = 0.75; c.wind = 0.2
        case .heavyRain:
            c.cloudCover = 1; c.cloudTone = .storm; c.deck = 1
            c.rain = 1; c.rainStyle = .heavy; c.fog = 0.2; c.wind = 0.35
        case .freezingRain:
            c.cloudCover = 1; c.cloudTone = .dark; c.deck = 0.8
            c.rain = 0.6; c.ice = 0.35; c.frost = 1
        case .sleet:
            c.cloudCover = 1; c.cloudTone = .gray; c.deck = 0.7
            c.rain = 0.4; c.rainStyle = .drizzle; c.ice = 0.8; c.frost = 0.5; c.wind = 0.25
        case .snow:
            c.cloudCover = 0.9; c.cloudTone = .gray; c.deck = 0.5; c.snow = 0.65; c.fog = 0.12
        case .blizzard:
            c.cloudCover = 1; c.cloudTone = .gray; c.deck = 0.8; c.snow = 1; c.blizzard = true
            c.wind = 1; c.fog = 0.45; c.frost = 0.7; c.windStreaks = 0.45; c.cloudSpeed = 2
        case .thunderstorm:
            c.cloudCover = 1; c.cloudTone = .storm; c.deck = 1
            c.rain = 0.9; c.rainStyle = .heavy; c.lightning = 1; c.wind = 0.5
        case .hail:
            c.cloudCover = 1; c.cloudTone = .storm; c.deck = 1
            c.hail = 1; c.rain = 0.45; c.lightning = 0.6; c.wind = 0.3
        }
        if let windKmh {
            c.wind = max(c.wind, min(1, max(0, (windKmh - 5) / 55)))
        }
        if !isDay {
            c.cloudTone = c.cloudTone.atNight
            c.motes = 0
        } else {
            c.stars = 0
        }
        c.sky = SkyPalette.colors(kind, isDay: isDay)
        return c
    }
}

/// Sky gradients — deep, muted ORBIS tones; never cartoon blue.
enum SkyPalette {
    static func colors(_ kind: WeatherKind, isDay: Bool) -> [UInt32] {
        if isDay {
            switch kind {
            case .clear, .mostlyClear: return [0x081B36, 0x154172, 0x3A6896, 0x8DA3B9]
            case .partlyCloudy, .windy: return [0x0C1F3C, 0x1D426C, 0x47698C, 0x8094A8]
            case .overcast: return [0x19212C, 0x2B3543, 0x46505E, 0x606976]
            case .fog: return [0x2A323C, 0x4A5360, 0x6B7480, 0x8C949D]
            case .drizzle: return [0x17212D, 0x2A3747, 0x44515E, 0x5C6672]
            case .rain: return [0x111923, 0x212E3E, 0x35424E, 0x4A5560]
            case .heavyRain: return [0x0A1018, 0x17212D, 0x26313E, 0x36404B]
            case .freezingRain, .sleet: return [0x1B2735, 0x324558, 0x54677B, 0x7B8C9F]
            case .snow: return [0x2A394E, 0x4A5C74, 0x74869F, 0xA3B1C2]
            case .blizzard: return [0x3A4555, 0x5B6878, 0x7E8A99, 0xA6AFBA]
            case .thunderstorm: return [0x06080D, 0x111621, 0x1D2430, 0x2A313F]
            case .hail: return [0x090C12, 0x161C27, 0x252D3A, 0x364050]
            }
        }
        switch kind {
        case .clear, .mostlyClear: return [0x020409, 0x070A0F, 0x0A1628, 0x16263E]
        case .partlyCloudy, .windy: return [0x04060B, 0x0A0F18, 0x0F1B2E, 0x1B2940]
        case .fog: return [0x0E1218, 0x1A2029, 0x272E38, 0x363D48]
        case .snow, .blizzard, .freezingRain, .sleet: return [0x0A111D, 0x15202F, 0x222D3F, 0x323E52]
        case .thunderstorm, .hail, .heavyRain: return [0x020305, 0x07090D, 0x0D1117, 0x151A22]
        default: return [0x05070B, 0x0D1117, 0x151C26, 0x1E2633]
        }
    }
}
