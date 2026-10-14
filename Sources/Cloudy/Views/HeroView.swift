import SwiftUI

/// The main card: city and reading on paper, the live animated sky beside it, and the
/// next 24 hours along the bottom.
struct HeroView: View {
    @EnvironmentObject private var store: WeatherStore
    @State private var parallax = ParallaxDriver()

    var body: some View {
        let place = store.selected
        WidgetCard(eyebrow: eyebrow(place), title: place?.name ?? "Cloudy", status: status) {
            if let place, place.isCurrentLocation { SignalTag(text: "Here") }
        } content: {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    reading
                        .frame(width: 300, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    sky.hairline(.leading)
                }
                .frame(maxHeight: .infinity)
                HourlyStrip().hairline(.top)
            }
        }
        .frame(minHeight: 420)
    }

    private func eyebrow(_ place: Place?) -> String {
        guard let place else { return "Live weather" }
        return place.subtitle.isEmpty ? place.coordinateLabel : "\(place.subtitle) · \(place.coordinateLabel)"
    }

    private var status: String {
        guard let f = store.forecast else { return "" }
        return "Updated \(Fmt.time(in: .current).string(from: f.fetchedAt)) · Open-Meteo"
    }

    @ViewBuilder
    private var reading: some View {
        if let f = store.forecast {
            let temp = store.unit.temp(f.current.temperature)
            VStack(alignment: .leading, spacing: 0) {
                TimelineView(.everyMinute) { tl in
                    Text("Local \(Fmt.time(in: f.timeZone).string(from: tl.date))").eyebrow(V3.mute, size: 7.5)
                }
                HStack(alignment: .top, spacing: 2) {
                    Text("\(temp)")
                        .font(V3Font.condensed(112, .ultraLight))
                        .foregroundStyle(V3.ink)
                        .contentTransition(.numericText(value: Double(temp)))
                        .monospacedDigit()
                    Text(store.unit.symbol)
                        .eyebrow(V3.mute, size: 11)
                        .padding(.top, 26)
                }
                .frame(height: 118)
                HStack(spacing: 8) {
                    WeatherGlyph(kind: f.kind, isDay: f.current.isDay, size: 17)
                    Text(WeatherKind.describe(code: f.current.code))
                        .font(V3Font.condensed(22, .medium))
                        .foregroundStyle(V3.ink)
                        .lineLimit(1)
                }
                if let today = f.today {
                    HStack(spacing: 12) {
                        Text("H \(store.unit.temp(today.high))°")
                        Text("L \(store.unit.temp(today.low))°")
                        Text("Feels \(store.unit.temp(f.current.apparent))°")
                    }
                    .eyebrow(V3.mute, size: 8)
                    .padding(.top, 8)
                }
                Spacer(minLength: 12)
                Text(f.headline(unit: store.unit))
                    .font(V3Font.condensed(16))
                    .foregroundStyle(V3.ink)
                    .lineLimit(2)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) { V3.signal.frame(width: 3) }
            }
            .id(store.selectedID)
            .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reading the sky").eyebrow(V3.mute, size: 8)
                ShimmerBar().frame(width: 150, height: 96)
                ShimmerBar().frame(width: 220, height: 16)
                ShimmerBar().frame(width: 180, height: 12)
            }
        }
    }

    private var sky: some View {
        GeometryReader { geo in
            WeatherBackdrop(config: store.sceneConfig, parallax: parallax)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 6) {
                        Text(store.sceneConfig.kind.title).eyebrow(.white.opacity(0.85), size: 7.5)
                        Text(store.sceneIsDay ? "Day" : "Night").eyebrow(.white.opacity(0.5), size: 7.5)
                        if store.preview != nil { SignalTag(text: "Preview") }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.35))
                    .padding(12)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p):
                        parallax.target = CGSize(width: (p.x / max(1, geo.size.width) - 0.5) * 2,
                                                 height: (p.y / max(1, geo.size.height) - 0.5) * 2)
                    case .ended:
                        parallax.target = .zero
                    }
                }
        }
        .clipped()
    }
}
