import WidgetKit
import Foundation

struct PlaceWeather: Identifiable {
    var place: Place
    var forecast: Forecast?
    var id: String { place.id }
}

struct CloudyEntry: TimelineEntry {
    var date: Date
    var cities: [PlaceWeather]
    var unit: TempUnit
    var isSample = false

    var primary: PlaceWeather? { cities.first }
}

/// Reading of the sky at a given moment: the live "current" for this hour,
/// the hourly forecast for later entries.
struct Reading {
    var temperature: Double
    var code: Int
    var isDay: Bool
    var kind: WeatherKind
}

extension Forecast {
    func reading(at date: Date) -> Reading {
        if date.timeIntervalSince(current.time) < 3600 {
            return Reading(temperature: current.temperature, code: current.code, isDay: current.isDay, kind: kind)
        }
        let hour = hours.last { $0.date <= date } ?? hours.first
        guard let hour else {
            return Reading(temperature: current.temperature, code: current.code, isDay: current.isDay, kind: kind)
        }
        return Reading(temperature: hour.temperature, code: hour.code, isDay: hour.isDay,
                       kind: .from(code: hour.code, temperature: hour.temperature))
    }

    func day(for date: Date) -> Day? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return days.first { cal.isDate($0.date, inSameDayAs: date) } ?? days.first
    }
}

struct CloudyProvider: TimelineProvider {
    /// Widgets that show only the selected city fetch one forecast; the city list fetches all.
    var allCities = false

    func placeholder(in context: Context) -> CloudyEntry { .sample(allCities: allCities) }

    func getSnapshot(in context: Context, completion: @escaping (CloudyEntry) -> Void) {
        if context.isPreview {
            completion(.sample(allCities: allCities))
            return
        }
        Task { completion(await load().first ?? .sample(allCities: allCities)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CloudyEntry>) -> Void) {
        Task {
            let entries = await load()
            let fetched = entries.first?.cities.contains { $0.forecast != nil } ?? false
            // Refresh every half hour; retry sooner when offline.
            let next = Date.now.addingTimeInterval(fetched ? 1800 : 900)
            completion(Timeline(entries: entries.isEmpty ? [.sample(allCities: allCities)] : entries,
                                policy: .after(next)))
        }
    }

    private func load() async -> [CloudyEntry] {
        let snapshot = SharedStore.load()
        var places = snapshot?.places ?? [WidgetDefaults.fallbackPlace]
        if let id = snapshot?.selectedID, let i = places.firstIndex(where: { $0.id == id }) {
            places.insert(places.remove(at: i), at: 0)
        }
        if !allCities { places = Array(places.prefix(1)) } else { places = Array(places.prefix(6)) }
        let unit = snapshot?.unit ?? .celsius

        let cities = await withTaskGroup(of: (Int, PlaceWeather).self) { group in
            for (i, place) in places.enumerated() {
                group.addTask { (i, PlaceWeather(place: place, forecast: try? await OpenMeteo.forecast(for: place))) }
            }
            var out: [(Int, PlaceWeather)] = []
            for await r in group { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // One entry per hour for the next six hours, so the sky and temperature
        // keep up with the hourly forecast between fetches.
        let now = Date.now
        let startOfHour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        var entries = [CloudyEntry(date: now, cities: cities, unit: unit)]
        for h in 1...6 {
            entries.append(CloudyEntry(date: startOfHour.addingTimeInterval(Double(h) * 3600), cities: cities, unit: unit))
        }
        return entries
    }
}

enum WidgetDefaults {
    static let fallbackPlace = Place(name: "Innsbruck", region: "Tyrol", country: "Austria",
                                     latitude: 47.2692, longitude: 11.4041)
}

// MARK: - Sample data (gallery + placeholders)

extension CloudyEntry {
    static func sample(allCities: Bool) -> CloudyEntry {
        let tz = TimeZone.current
        let now = Date.now
        func forecast(_ temp: Double, _ code: Int, high: Double, low: Double) -> Forecast {
            let hours = (0..<30).map { h in
                Forecast.Hour(date: now.addingTimeInterval(Double(h) * 3600), temperature: temp + sin(Double(h) / 4) * 3,
                              code: [code, code, 2, 3, 61, 1][h % 6], precipProbability: [0, 10, 30, 60, 20, 0][h % 6], isDay: true)
            }
            let days = (0..<10).map { d in
                Forecast.Day(date: now.addingTimeInterval(Double(d) * 86_400), code: [code, 3, 61, 2, 0, 71, 95, 1, 2, 3][d],
                             high: high + Double(d % 3), low: low - Double(d % 2), sunrise: nil, sunset: nil,
                             uvMax: 3, precipProbability: [0, 20, 70, 10, 0, 40, 80, 0, 10, 20][d])
            }
            let current = Forecast.Current(time: now, temperature: temp, apparent: temp - 1, humidity: 60, dewPoint: 6,
                                           isDay: true, precipitation: 0, code: code, cloudCover: 40, pressure: 1016,
                                           windSpeed: 9, windDirection: 220, windGusts: 18, visibility: 24_000, uvIndex: 2)
            return Forecast(timeZone: tz, current: current, hours: hours, days: days, fetchedAt: now)
        }
        var cities = [PlaceWeather(place: WidgetDefaults.fallbackPlace, forecast: forecast(14, 2, high: 17, low: 8))]
        if allCities {
            cities += [
                PlaceWeather(place: Place(name: "Vienna", latitude: 48.2, longitude: 16.37), forecast: forecast(16, 0, high: 19, low: 10)),
                PlaceWeather(place: Place(name: "London", latitude: 51.5, longitude: -0.12), forecast: forecast(12, 61, high: 14, low: 9)),
                PlaceWeather(place: Place(name: "Tokyo", latitude: 35.7, longitude: 139.7), forecast: forecast(21, 3, high: 23, low: 17)),
            ]
        }
        return CloudyEntry(date: now, cities: cities, unit: .celsius, isSample: true)
    }
}
