import SwiftUI
import WidgetKit

// MARK: - Sky background

/// A still frame of the app's animated sky. The scene is drawn at a larger
/// virtual size and scaled down, so clouds and sun keep their proportions.
struct WidgetSky: View {
    let kind: WeatherKind
    let isDay: Bool

    var body: some View {
        Canvas { ctx, size in
            let k = max(0.42, min(1, size.width / 820))
            ctx.scaleBy(x: k, y: k)
            let virtual = CGSize(width: size.width / k, height: size.height / k)
            let config = SceneConfig.make(kind: kind, isDay: isDay, windKmh: nil)
            SceneRenderer(c: config, t: 14.2, size: virtual, px: .zero).draw(&ctx)
        }
        .overlay(
            LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.05), .black.opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

/// Text colours that stay legible when the desktop renders widgets
/// in the monochrome "vibrant" style.
private struct Palette {
    let mode: WidgetRenderingMode
    var full: Bool { mode == .fullColor }
    var ink: Color { full ? .white : .primary }
    var muted: Color { full ? .white.opacity(0.62) : .secondary }
    var gold: Color { full ? V3.signal : .primary }
}

private struct Degrees: View {
    let value: Int
    let size: CGFloat
    let palette: Palette

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            Text("\(value)")
                .font(V3Font.condensed(size, .ultraLight))
                .foregroundStyle(palette.ink)
                .contentTransition(.numericText(value: Double(value)))
            Text("°")
                .font(V3Font.condensed(size * 0.42, .ultraLight))
                .foregroundStyle(palette.gold)
                .padding(.top, size * 0.12)
        }
        .monospacedDigit()
    }
}

private struct CityHeader: View {
    let place: Place
    let palette: Palette
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 5) {
            if place.isCurrentLocation {
                Image(systemName: "location.fill").font(.system(size: size * 0.7, weight: .semibold))
                    .foregroundStyle(palette.gold)
            }
            Text(place.name)
                .font(V3Font.condensed(size * 1.2, .demiBold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Rectangle().fill(palette.gold).frame(width: 5, height: 5)
        }
    }
}

// MARK: - "Now" widget

struct NowWidgetView: View {
    let entry: CloudyEntry
    /// Lets the snapshot harness pick a size (the environment value is read-only).
    var familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var envFamily
    private var family: WidgetFamily { familyOverride ?? envFamily }
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let palette = Palette(mode: mode)
        Group {
            if let city = entry.primary, let f = city.forecast {
                let r = f.reading(at: entry.date)
                content(city.place, f, r, palette)
                    .containerBackground(for: .widget) { WidgetSky(kind: r.kind, isDay: r.isDay) }
                    .widgetURL(SharedStore.url(for: city.place))
            } else {
                Unavailable(name: entry.primary?.place.name, palette: palette)
                    .containerBackground(for: .widget) { WidgetSky(kind: .overcast, isDay: false) }
            }
        }
    }

    @ViewBuilder
    private func content(_ place: Place, _ f: Forecast, _ r: Reading, _ p: Palette) -> some View {
        switch family {
        case .systemMedium: medium(place, f, r, p)
        case .systemLarge, .systemExtraLarge: large(place, f, r, p)
        default: small(place, f, r, p)
        }
    }

    private func summary(_ place: Place, _ f: Forecast, _ r: Reading, _ p: Palette, tempSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CityHeader(place: place, palette: p)
            Degrees(value: entry.unit.temp(r.temperature), size: tempSize, palette: p)
                .padding(.top, -2)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                WeatherGlyph(kind: r.kind, isDay: r.isDay, size: 12, ink: p.ink)
                Text(WeatherKind.describe(code: r.code))
                    .font(V3Font.condensed(13.8, .medium))
                    .foregroundStyle(p.ink)
                    .lineLimit(1)
            }
            if let day = f.day(for: entry.date) {
                Text("H \(entry.unit.temp(day.high))°  L \(entry.unit.temp(day.low))°")
                    .font(V3Font.mono(9, .medium))
                    .foregroundStyle(p.muted)
                    .padding(.top, 3)
            }
        }
    }

    private func small(_ place: Place, _ f: Forecast, _ r: Reading, _ p: Palette) -> some View {
        summary(place, f, r, p, tempSize: 50)
    }

    private func medium(_ place: Place, _ f: Forecast, _ r: Reading, _ p: Palette) -> some View {
        HStack(spacing: 14) {
            summary(place, f, r, p, tempSize: 52)
                .frame(width: 128)
            VStack(alignment: .leading, spacing: 8) {
                Text(f.headline(unit: entry.unit, now: entry.date))
                    .font(V3Font.condensed(13))
                    .foregroundStyle(p.ink.opacity(0.85))
                    .lineLimit(2)
                Spacer(minLength: 0)
                HourRow(forecast: f, from: entry.date, count: 5, unit: entry.unit, palette: p)
            }
        }
    }

    private func large(_ place: Place, _ f: Forecast, _ r: Reading, _ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    CityHeader(place: place, palette: p, size: 14)
                    Degrees(value: entry.unit.temp(r.temperature), size: 60, palette: p)
                    HStack(spacing: 5) {
                        WeatherGlyph(kind: r.kind, isDay: r.isDay, size: 13, ink: p.ink)
                        Text(WeatherKind.describe(code: r.code))
                            .font(V3Font.condensed(15, .medium))
                            .foregroundStyle(p.ink)
                    }
                    Text(f.headline(unit: entry.unit, now: entry.date))
                        .font(V3Font.condensed(13))
                        .foregroundStyle(p.ink.opacity(0.85))
                        .lineLimit(1)
                        .padding(.top, 4)
                }
            }
            HourRow(forecast: f, from: entry.date, count: 6, unit: entry.unit, palette: p)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Rectangle().fill(.black.opacity(p.full ? 0.28 : 0.1)))
            DayList(forecast: f, count: 5, unit: entry.unit, palette: p)
        }
    }
}

private struct HourRow: View {
    let forecast: Forecast
    let from: Date
    let count: Int
    let unit: TempUnit
    let palette: Palette

    var body: some View {
        let hours = Array(forecast.hours.filter { $0.date >= from.addingTimeInterval(-3599) }.prefix(count))
        HStack(spacing: 0) {
            ForEach(Array(hours.enumerated()), id: \.element.id) { i, h in
                VStack(spacing: 5) {
                    Text(i == 0 ? "Now" : Fmt.hour(in: forecast.timeZone).string(from: h.date))
                        .font(V3Font.mono(8.6, .bold))
                        .foregroundStyle(i == 0 ? palette.gold : palette.muted)
                    WeatherGlyph(kind: h.kind, isDay: h.isDay, size: 13, ink: palette.ink)
                        .frame(height: 16)
                    Text("\(unit.temp(h.temperature))°")
                        .font(V3Font.condensed(14.4, .medium))
                        .foregroundStyle(palette.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct DayList: View {
    let forecast: Forecast
    let count: Int
    let unit: TempUnit
    let palette: Palette

    var body: some View {
        let days = Array(forecast.days.prefix(count))
        let lo = days.map(\.low).min() ?? 0
        let hi = max(days.map(\.high).max() ?? 1, lo + 1)
        VStack(spacing: 7) {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                HStack(spacing: 8) {
                    Text(i == 0 ? "Today" : Fmt.weekday(in: forecast.timeZone).string(from: d.date))
                        .font(V3Font.condensed(14.4, i == 0 ? .demiBold : .regular))
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, alignment: .leading)
                    WeatherGlyph(kind: d.kind, isDay: true, size: 12, ink: palette.ink)
                        .frame(width: 22)
                    Text("\(unit.temp(d.low))°")
                        .font(V3Font.mono(9.5, .medium))
                        .foregroundStyle(palette.muted)
                        .frame(width: 28, alignment: .trailing)
                    TempRangeBar(low: d.low, high: d.high, range: lo...hi,
                                 now: i == 0 ? forecast.current.temperature : nil,
                                 ink: palette.ink, track: palette.ink.opacity(0.18))
                        .frame(height: 4)
                    Text("\(unit.temp(d.high))°")
                        .font(V3Font.mono(9.5, .semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 28, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Cities widget

struct CitiesWidgetView: View {
    let entry: CloudyEntry
    /// Lets the snapshot harness pick a size (the environment value is read-only).
    var familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var envFamily
    private var family: WidgetFamily { familyOverride ?? envFamily }
    /// `Link` can't be drawn by ImageRenderer, so the snapshot harness turns it off.
    var links = true
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let p = Palette(mode: mode)
        let rows = Array(entry.cities.prefix(family == .systemLarge ? 6 : 3))
        let lead = entry.primary?.forecast?.reading(at: entry.date)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CLOUDY")
                    .font(V3Font.condensed(12, .demiBold))
                    .tracking(3)
                    .foregroundStyle(p.ink)
                Rectangle().fill(p.gold).frame(width: 4, height: 4)
                Spacer()
                Text("CITIES").font(V3Font.mono(8.1, .medium)).tracking(1.4).foregroundStyle(p.muted)
            }
            .padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, city in
                if i > 0 { Rectangle().fill(p.ink.opacity(0.1)).frame(height: 1) }
                Group {
                    if links {
                        Link(destination: SharedStore.url(for: city.place) ?? URL(string: "cloudy://")!) {
                            CityRow(city: city, date: entry.date, unit: entry.unit, palette: p)
                        }
                    } else {
                        CityRow(city: city, date: entry.date, unit: entry.unit, palette: p)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) { WidgetSky(kind: lead?.kind ?? .partlyCloudy, isDay: lead?.isDay ?? true) }
    }
}

private struct CityRow: View {
    let city: PlaceWeather
    let date: Date
    let unit: TempUnit
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            if let f = city.forecast {
                let r = f.reading(at: date)
                WeatherGlyph(kind: r.kind, isDay: r.isDay, size: 15, ink: palette.ink)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(city.place.name)
                        .font(V3Font.condensed(15.6, .demiBold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(WeatherKind.describe(code: r.code))
                        .font(V3Font.condensed(12.6))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let d = f.day(for: date) {
                    Text("\(unit.temp(d.high))° / \(unit.temp(d.low))°")
                        .font(V3Font.mono(8.6, .medium))
                        .foregroundStyle(palette.muted)
                }
                Text("\(unit.temp(r.temperature))°")
                    .font(V3Font.condensed(24, .ultraLight))
                    .foregroundStyle(palette.ink)
                    .frame(minWidth: 40, alignment: .trailing)
            } else {
                Image(systemName: "wifi.slash").foregroundStyle(palette.muted).frame(width: 24)
                Text(city.place.name).font(V3Font.condensed(15.6, .demiBold)).foregroundStyle(palette.ink)
                Spacer()
                Text("—").foregroundStyle(palette.muted)
            }
        }
    }
}

private struct Unavailable: View {
    let name: String?
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "cloud.fill").foregroundStyle(palette.gold)
            Text(name ?? "Cloudy").font(V3Font.condensed(15.6, .demiBold)).foregroundStyle(palette.ink)
            Text("Waiting for the sky…")
                .font(V3Font.condensed(13))
                .foregroundStyle(palette.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
