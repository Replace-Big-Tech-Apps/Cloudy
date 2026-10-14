import Foundation

/// Open-Meteo client — free, keyless forecast + geocoding.
enum OpenMeteo {
    enum Failure: LocalizedError {
        case badResponse
        var errorDescription: String? { "Open-Meteo returned an unexpected response." }
    }

    static func forecast(for place: Place) async throws -> Forecast {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(place.latitude)),
            .init(name: "longitude", value: String(place.longitude)),
            .init(name: "current", value: [
                "temperature_2m", "apparent_temperature", "relative_humidity_2m", "dew_point_2m",
                "is_day", "precipitation", "weather_code", "cloud_cover", "pressure_msl",
                "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m", "visibility", "uv_index",
            ].joined(separator: ",")),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            .init(name: "daily", value: [
                "weather_code", "temperature_2m_max", "temperature_2m_min", "sunrise", "sunset",
                "uv_index_max", "precipitation_probability_max",
            ].joined(separator: ",")),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "10"),
        ]
        let (data, response) = try await URLSession.shared.data(from: c.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badResponse }
        return try JSONDecoder().decode(ForecastDTO.self, from: data).domain()
    }

    static func search(_ query: String) async throws -> [Place] {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "8"),
            .init(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"),
            .init(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        let dto = try JSONDecoder().decode(GeocodeDTO.self, from: data)
        return (dto.results ?? []).map {
            Place(name: $0.name, region: $0.admin1, country: $0.country,
                  latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}

// MARK: - Wire format

private struct GeocodeDTO: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
    }
    let results: [Result]?
}

private struct ForecastDTO: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature: Double
        let apparent: Double
        let humidity: Double
        let dewPoint: Double?
        let isDay: Int
        let precipitation: Double?
        let weatherCode: Int
        let cloudCover: Double?
        let pressure: Double?
        let windSpeed: Double
        let windDirection: Double
        let windGusts: Double?
        let visibility: Double?
        let uvIndex: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparent = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case dewPoint = "dew_point_2m"
            case isDay = "is_day"
            case precipitation
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case pressure = "pressure_msl"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
            case windGusts = "wind_gusts_10m"
            case visibility
            case uvIndex = "uv_index"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double?]
        let weatherCode: [Int?]
        let precipitationProbability: [Int?]?
        let isDay: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitationProbability = "precipitation_probability"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int?]
        let high: [Double?]
        let low: [Double?]
        let sunrise: [String?]
        let sunset: [String?]
        let uvIndexMax: [Double?]?
        let precipitationProbabilityMax: [Int?]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case high = "temperature_2m_max"
            case low = "temperature_2m_min"
            case sunrise, sunset
            case uvIndexMax = "uv_index_max"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }

    let timezone: String
    let utcOffsetSeconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case timezone, current, hourly, daily
        case utcOffsetSeconds = "utc_offset_seconds"
    }

    func domain() -> Forecast {
        let tz = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .current

        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = tz
        stamp.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = tz
        day.dateFormat = "yyyy-MM-dd"

        let cur = Forecast.Current(
            time: stamp.date(from: current.time) ?? .now,
            temperature: current.temperature,
            apparent: current.apparent,
            humidity: current.humidity,
            dewPoint: current.dewPoint,
            isDay: current.isDay == 1,
            precipitation: current.precipitation ?? 0,
            code: current.weatherCode,
            cloudCover: current.cloudCover,
            pressure: current.pressure,
            windSpeed: current.windSpeed,
            windDirection: current.windDirection,
            windGusts: current.windGusts,
            visibility: current.visibility,
            uvIndex: current.uvIndex
        )

        var hours: [Forecast.Hour] = []
        for i in hourly.time.indices {
            guard let date = stamp.date(from: hourly.time[i]),
                  let temp = hourly.temperature[safe: i] ?? nil,
                  let code = hourly.weatherCode[safe: i] ?? nil else { continue }
            hours.append(.init(
                date: date, temperature: temp, code: code,
                precipProbability: hourly.precipitationProbability?[safe: i] ?? nil,
                isDay: (hourly.isDay[safe: i] ?? 1) == 1
            ))
        }

        var days: [Forecast.Day] = []
        for i in daily.time.indices {
            guard let date = day.date(from: daily.time[i]),
                  let hi = daily.high[safe: i] ?? nil,
                  let lo = daily.low[safe: i] ?? nil else { continue }
            days.append(.init(
                date: date,
                code: (daily.weatherCode[safe: i] ?? nil) ?? 2,
                high: hi, low: lo,
                sunrise: (daily.sunrise[safe: i] ?? nil).flatMap(stamp.date(from:)),
                sunset: (daily.sunset[safe: i] ?? nil).flatMap(stamp.date(from:)),
                uvMax: daily.uvIndexMax?[safe: i] ?? nil,
                precipProbability: daily.precipitationProbabilityMax?[safe: i] ?? nil
            ))
        }

        return Forecast(timeZone: tz, current: cur, hours: hours, days: days, fetchedAt: .now)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
