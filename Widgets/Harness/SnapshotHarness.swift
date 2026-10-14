import SwiftUI
import WidgetKit
import AppKit

/// Dev tool: renders every widget/size to PNG with live data, without the
/// widget host. Built by `scripts/widget_snapshots.sh`.
@main
struct SnapshotHarness {
    static let sizes: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 170, height: 170), "small"),
        (.systemMedium, CGSize(width: 364, height: 170), "medium"),
        (.systemLarge, CGSize(width: 364, height: 382), "large"),
    ]

    @MainActor
    static func main() async {
        let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "widget-snapshots")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let places = [
            Place(name: "Wattens", region: "Tirol", country: "Österreich", latitude: 47.29, longitude: 11.59, isCurrentLocation: true),
            Place(name: "Vienna", latitude: 48.2085, longitude: 16.3721),
            Place(name: "London", latitude: 51.5085, longitude: -0.1257),
            Place(name: "Tokyo", latitude: 35.6895, longitude: 139.6917),
            Place(name: "Reykjavík", latitude: 64.1355, longitude: -21.8954),
            Place(name: "Cairo", latitude: 30.0444, longitude: 31.2357),
        ]
        var cities: [PlaceWeather] = []
        for p in places { cities.append(PlaceWeather(place: p, forecast: try? await OpenMeteo.forecast(for: p))) }
        let entry = CloudyEntry(date: .now, cities: cities, unit: .celsius)

        for (family, size, name) in sizes {
            let r = cities[0].forecast?.reading(at: entry.date)
            render(NowWidgetView(entry: entry, familyOverride: family), kind: r?.kind ?? .overcast,
                   isDay: r?.isDay ?? false, size: size, to: out.appendingPathComponent("now-\(name).png"))
            if family != .systemSmall {
                render(CitiesWidgetView(entry: entry, familyOverride: family, links: false), kind: r?.kind ?? .overcast,
                       isDay: r?.isDay ?? false, size: size, to: out.appendingPathComponent("cities-\(name).png"))
            }
        }
        // Every sky in a small widget, for a look at the backgrounds.
        for kind in WeatherKind.allCases {
            for day in [true, false] {
                var e = CloudyEntry.sample(allCities: false)
                e.cities[0].forecast?.current.code = sampleCode(kind)
                e.cities[0].forecast?.current.isDay = day
                render(NowWidgetView(entry: e, familyOverride: .systemSmall), kind: kind, isDay: day,
                       size: CGSize(width: 170, height: 170),
                       to: out.appendingPathComponent("sky-\(kind.rawValue)-\(day ? "day" : "night").png"))
            }
        }
        print("Snapshots in \(out.path)")
    }

    static func sampleCode(_ k: WeatherKind) -> Int {
        switch k {
        case .clear: 0; case .mostlyClear: 1; case .partlyCloudy: 2; case .overcast: 3; case .fog: 45
        case .windy: 2; case .drizzle: 53; case .rain: 63; case .heavyRain: 65; case .freezingRain: 67
        case .sleet: 66; case .snow: 73; case .blizzard: 75; case .thunderstorm: 95; case .hail: 99
        }
    }

    @MainActor
    static func render<V: View>(_ view: V, kind: WeatherKind, isDay: Bool, size: CGSize, to url: URL) {
        let card = ZStack {
            WidgetSky(kind: kind, isDay: isDay)
            view.padding(16)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}
