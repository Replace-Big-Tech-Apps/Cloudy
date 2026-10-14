import Foundation

/// The app ↔ widget handshake: saved cities, the selected one, and units,
/// written as JSON into the shared App Group container.
enum SharedStore {
    struct Snapshot: Codable {
        var places: [Place]
        var selectedID: String?
        var unit: TempUnit
    }

    /// Set by the build script in both Info.plists (team-prefixed group id).
    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "CloudyAppGroup") as? String
    }

    private static var fileURL: URL? {
        guard let groupID,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else { return nil }
        return dir.appendingPathComponent("shared.json")
    }

    static func save(_ snapshot: Snapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> Snapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// `cloudy://place/<id>` — widget taps open straight to a city.
    static func url(for place: Place) -> URL? {
        var c = URLComponents()
        c.scheme = "cloudy"
        c.host = "place"
        c.queryItems = [URLQueryItem(name: "id", value: place.id)]
        return c.url
    }

    static func placeID(from url: URL) -> String? {
        guard url.scheme == "cloudy", url.host == "place" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
    }
}
