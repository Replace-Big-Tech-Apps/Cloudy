import Foundation

struct Place: Codable, Hashable, Identifiable {
    var name: String
    var region: String?
    var country: String?
    var latitude: Double
    var longitude: Double
    var isCurrentLocation: Bool = false

    var id: String {
        isCurrentLocation ? "current" : String(format: "%.3f,%.3f", latitude, longitude)
    }

    var subtitle: String {
        [region, country].compactMap { $0 }.filter { !$0.isEmpty && $0 != name }.joined(separator: ", ")
    }

    var coordinateLabel: String {
        let lat = String(format: "%.2f°%@", abs(latitude), latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.2f°%@", abs(longitude), longitude >= 0 ? "E" : "W")
        return "\(lat)  \(lon)"
    }
}

struct Forecast {
    struct Current {
        var time: Date
        var temperature: Double
        var apparent: Double
        var humidity: Double
        var dewPoint: Double?
        var isDay: Bool
        var precipitation: Double
        var code: Int
        var cloudCover: Double?
        var pressure: Double?
        var windSpeed: Double
        var windDirection: Double
        var windGusts: Double?
        var visibility: Double?
        var uvIndex: Double?
    }

    struct Hour: Identifiable {
        var date: Date
        var temperature: Double
        var code: Int
        var precipProbability: Int?
        var isDay: Bool
        var id: Date { date }
        var kind: WeatherKind { .from(code: code, temperature: temperature) }
    }

    struct Day: Identifiable {
        var date: Date
        var code: Int
        var high: Double
        var low: Double
        var sunrise: Date?
        var sunset: Date?
        var uvMax: Double?
        var precipProbability: Int?
        var id: Date { date }
        var kind: WeatherKind { .from(code: code, temperature: (high + low) / 2) }
    }

    enum HourItem: Identifiable {
        case hour(Hour, isNow: Bool)
        case sun(Date, rising: Bool)

        var id: String {
            switch self {
            case .hour(let h, _): "h\(h.date.timeIntervalSince1970)"
            case .sun(let d, let r): "s\(r)\(d.timeIntervalSince1970)"
            }
        }

        var date: Date {
            switch self {
            case .hour(let h, _): h.date
            case .sun(let d, _): d
            }
        }
    }

    var timeZone: TimeZone
    var current: Current
    var hours: [Hour]
    var days: [Day]
    var fetchedAt: Date

    var kind: WeatherKind {
        .from(code: current.code, temperature: current.temperature, windKmh: current.windSpeed)
    }

    var today: Day? { days.first }

    /// The next 24 hours, interleaved with sunrise / sunset moments.
    func upcoming(now: Date = .now, count: Int = 24) -> [HourItem] {
        guard !hours.isEmpty else { return [] }
        let start = hours.lastIndex { $0.date <= now } ?? 0
        let slice = Array(hours[start..<min(start + count + 1, hours.count)])
        guard let first = slice.first, let last = slice.last else { return [] }

        var items: [HourItem] = slice.enumerated().map { .hour($0.element, isNow: $0.offset == 0) }
        for day in days {
            for (date, rising) in [(day.sunrise, true), (day.sunset, false)] {
                if let date, date > first.date, date <= last.date {
                    items.append(.sun(date, rising: rising))
                }
            }
        }
        return items.sorted { $0.date < $1.date }
    }

    /// A one-line, newspaper-style read of what the sky does next.
    func headline(unit: TempUnit, now: Date = .now) -> String {
        let next = hours.filter { $0.date > now }.prefix(24)
        let fmt = Fmt.time(in: timeZone)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        // "15:00" today, "tomorrow 12:00" after midnight.
        func when(_ date: Date) -> String {
            cal.isDate(date, inSameDayAs: now) ? fmt.string(from: date) : "tomorrow \(fmt.string(from: date))"
        }
        let wetNow = kind.isWet || [.snow, .blizzard].contains(kind)

        if wetNow {
            if let dry = next.first(where: { ($0.precipProbability ?? 0) < 25 }) {
                return "\(precipNoun(kind)) easing around \(when(dry.date))."
            }
            return "\(precipNoun(kind)) settling in for the day."
        }
        if let wet = next.first(where: { ($0.precipProbability ?? 0) >= 50 }) {
            return "\(precipNoun(wet.kind)) likely from \(when(wet.date))."
        }
        if let peak = next.prefix(14).max(by: { $0.temperature < $1.temperature }),
           peak.temperature > current.temperature + 1 {
            return "Dry skies, peaking at \(unit.temp(peak.temperature))° around \(when(peak.date))."
        }
        return "Dry for the next 24 hours."
    }

    private func precipNoun(_ kind: WeatherKind) -> String {
        switch kind {
        case .snow, .blizzard: "Snow"
        case .sleet, .freezingRain: "Sleet"
        case .thunderstorm, .hail: "Storms"
        case .drizzle: "Drizzle"
        default: "Rain"
        }
    }
}

// MARK: - Units & formatting

enum TempUnit: String, CaseIterable, Codable {
    case celsius, fahrenheit

    var symbol: String { self == .celsius ? "°C" : "°F" }

    func temp(_ c: Double) -> Int {
        Int((self == .celsius ? c : c * 9 / 5 + 32).rounded())
    }

    func wind(_ kmh: Double) -> (value: String, unit: String) {
        self == .celsius ? ("\(Int(kmh.rounded()))", "km/h") : ("\(Int((kmh * 0.621371).rounded()))", "mph")
    }

    func distance(_ meters: Double) -> (value: String, unit: String) {
        if self == .celsius {
            let km = meters / 1000
            return (km >= 10 ? "\(Int(km.rounded()))" : String(format: "%.1f", km), "km")
        }
        let mi = meters / 1609.34
        return (mi >= 10 ? "\(Int(mi.rounded()))" : String(format: "%.1f", mi), "mi")
    }
}

enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ key: String, _ tz: TimeZone, _ build: (DateFormatter) -> Void) -> DateFormatter {
        let id = key + tz.identifier
        if let f = cache[id] { return f }
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = .current
        build(f)
        cache[id] = f
        return f
    }

    static func time(in tz: TimeZone) -> DateFormatter {
        formatter("time", tz) { $0.setLocalizedDateFormatFromTemplate("jjmm") }
    }

    static func hour(in tz: TimeZone) -> DateFormatter {
        formatter("hour", tz) { $0.dateFormat = "HH" }
    }

    static func weekday(in tz: TimeZone) -> DateFormatter {
        formatter("weekday", tz) { $0.setLocalizedDateFormatFromTemplate("EEE") }
    }

    static func compass(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let i = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45)) % 8
        return points[i]
    }
}
