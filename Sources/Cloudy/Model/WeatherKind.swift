import Foundation

/// Every sky Cloudy knows how to animate. Mapped from WMO weather codes.
enum WeatherKind: String, CaseIterable, Identifiable, Codable {
    case clear
    case mostlyClear
    case partlyCloudy
    case overcast
    case fog
    case windy
    case drizzle
    case rain
    case heavyRain
    case freezingRain
    case sleet
    case snow
    case blizzard
    case thunderstorm
    case hail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: "Clear"
        case .mostlyClear: "Mostly Clear"
        case .partlyCloudy: "Partly Cloudy"
        case .overcast: "Overcast"
        case .fog: "Fog"
        case .windy: "Windy"
        case .drizzle: "Drizzle"
        case .rain: "Rain"
        case .heavyRain: "Heavy Rain"
        case .freezingRain: "Freezing Rain"
        case .sleet: "Sleet"
        case .snow: "Snow"
        case .blizzard: "Blizzard"
        case .thunderstorm: "Thunderstorm"
        case .hail: "Hail"
        }
    }

    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: isDay ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear: isDay ? "sun.min.fill" : "moon.fill"
        case .partlyCloudy: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .windy: "wind"
        case .drizzle: "cloud.drizzle.fill"
        case .rain: isDay ? "cloud.rain.fill" : "cloud.moon.rain.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .freezingRain: "cloud.sleet.fill"
        case .sleet: "cloud.sleet.fill"
        case .snow: "cloud.snow.fill"
        case .blizzard: "wind.snow"
        case .thunderstorm: "cloud.bolt.rain.fill"
        case .hail: "cloud.hail.fill"
        }
    }

    /// Whether the symbol contains a sun or moon worth tinting gold.
    var hasCelestialGlyph: Bool {
        switch self {
        case .clear, .mostlyClear, .partlyCloudy: true
        default: false
        }
    }

    static func from(code: Int, temperature: Double? = nil, windKmh: Double? = nil) -> WeatherKind {
        var kind: WeatherKind
        switch code {
        case 0: kind = .clear
        case 1: kind = .mostlyClear
        case 2: kind = .partlyCloudy
        case 3: kind = .overcast
        case 45, 48: kind = .fog
        case 51, 53, 55: kind = .drizzle
        case 56, 57, 66, 67: kind = .freezingRain
        case 61, 63, 80, 81: kind = .rain
        case 65, 82: kind = .heavyRain
        case 71, 73, 77, 85: kind = .snow
        case 75, 86: kind = .blizzard
        case 95: kind = .thunderstorm
        case 96, 99: kind = .hail
        default: kind = .partlyCloudy
        }
        // Rain falling right around freezing reads as sleet.
        if [.rain, .drizzle, .heavyRain].contains(kind), let t = temperature, t <= 1.5 {
            kind = .sleet
        }
        // A calm sky with a strong wind gets the windy treatment.
        if [.clear, .mostlyClear, .partlyCloudy, .overcast].contains(kind), let w = windKmh, w >= 38 {
            kind = .windy
        }
        return kind
    }

    /// Human description straight from the WMO code table.
    static func describe(code: Int) -> String {
        switch code {
        case 0: "Clear sky"
        case 1: "Mainly clear"
        case 2: "Partly cloudy"
        case 3: "Overcast"
        case 45: "Fog"
        case 48: "Rime fog"
        case 51: "Light drizzle"
        case 53: "Drizzle"
        case 55: "Dense drizzle"
        case 56: "Light freezing drizzle"
        case 57: "Freezing drizzle"
        case 61: "Light rain"
        case 63: "Rain"
        case 65: "Heavy rain"
        case 66: "Light freezing rain"
        case 67: "Freezing rain"
        case 71: "Light snow"
        case 73: "Snow"
        case 75: "Heavy snow"
        case 77: "Snow grains"
        case 80: "Light showers"
        case 81: "Showers"
        case 82: "Violent showers"
        case 85: "Snow showers"
        case 86: "Heavy snow showers"
        case 95: "Thunderstorm"
        case 96: "Thunderstorm with hail"
        case 99: "Severe thunderstorm, hail"
        default: "Unsettled"
        }
    }

    var isWet: Bool {
        switch self {
        case .drizzle, .rain, .heavyRain, .freezingRain, .sleet, .thunderstorm, .hail: true
        default: false
        }
    }
}
