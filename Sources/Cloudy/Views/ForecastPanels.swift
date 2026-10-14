import SwiftUI

// MARK: - 10-day

struct DailyPanel: View {
    @EnvironmentObject private var store: WeatherStore

    var body: some View {
        let f = store.forecast
        WidgetCard(eyebrow: "Forecast", title: "Next 10 days", status: f?.timeZone.abbreviation() ?? "") {
            if let f {
                let lo = f.days.map(\.low).min() ?? 0
                let hi = f.days.map(\.high).max() ?? 1
                VStack(spacing: 0) {
                    ForEach(Array(f.days.enumerated()), id: \.element.id) { i, day in
                        DayRow(day: day, isToday: i == 0, range: lo...max(hi, lo + 1),
                               now: i == 0 ? f.current.temperature : nil, tz: f.timeZone)
                    }
                }
                .id(store.selectedID)
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { _ in
                        ShimmerBar().frame(height: 14).padding(.horizontal, 17).frame(maxHeight: .infinity).hairline(.bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .animation(V3.Motion.slow, value: store.selectedID)
    }
}

private struct DayRow: View {
    @EnvironmentObject private var store: WeatherStore
    let day: Forecast.Day
    let isToday: Bool
    let range: ClosedRange<Double>
    let now: Double?
    let tz: TimeZone
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isToday ? "Today" : Fmt.weekday(in: tz).string(from: day.date))
                    .eyebrow(isToday ? V3.ink : V3.mute, size: 8)
                Text(day.date, format: .dateTime.day().month(.abbreviated))
                    .eyebrow(V3.whisper, size: 6.5)
            }
            .frame(width: 50, alignment: .leading)

            WeatherGlyph(kind: day.kind, isDay: true, size: 14)
                .frame(width: 24)

            Text((day.precipProbability ?? 0) >= 20 ? "\(day.precipProbability!)%" : "")
                .eyebrow(V3.mute, size: 7)
                .frame(width: 26, alignment: .leading)

            Text("\(store.unit.temp(day.low))°")
                .font(V3Font.condensed(17))
                .foregroundStyle(V3.mute)
                .frame(width: 30, alignment: .trailing)

            TempRangeBar(low: day.low, high: day.high, range: range, now: now)
                .frame(height: 3)

            Text("\(store.unit.temp(day.high))°")
                .font(V3Font.condensed(17, .medium))
                .foregroundStyle(V3.ink)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, 17)
        .frame(maxHeight: .infinity)
        .frame(minHeight: 44)
        .background(isToday ? V3.signalWash : (hover ? V3.paperSoft : V3.paper))
        .hairline(.bottom)
        .onHover { h in withAnimation(V3.Motion.fast) { hover = h } }
    }
}

// MARK: - Hourly

/// The next 24 hours as hairline-divided columns, with sunrise and sunset slotted in.
struct HourlyStrip: View {
    @EnvironmentObject private var store: WeatherStore

    var body: some View {
        Group {
            if let f = store.forecast {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(f.upcoming()) { item in
                            HourCell(item: item, tz: f.timeZone)
                        }
                    }
                }
                .id(store.selectedID)
                .transition(.opacity)
            } else {
                ShimmerBar().padding(14)
            }
        }
        .frame(height: 96)
        .animation(V3.Motion.slow, value: store.selectedID)
    }
}

private struct HourCell: View {
    @EnvironmentObject private var store: WeatherStore
    let item: Forecast.HourItem
    let tz: TimeZone
    @State private var hover = false

    var body: some View {
        VStack(spacing: 7) {
            switch item {
            case .hour(let h, let isNow):
                Text(isNow ? "Now" : Fmt.hour(in: tz).string(from: h.date))
                    .eyebrow(isNow ? V3.signal : V3.mute, size: 7.5)
                WeatherGlyph(kind: h.kind, isDay: h.isDay, size: 15, ink: isNow ? V3.inverse : V3.ink)
                    .frame(height: 20)
                Text("\(store.unit.temp(h.temperature))°")
                    .font(V3Font.condensed(20, .medium))
                    .foregroundStyle(isNow ? V3.inverse : V3.ink)
                Text((h.precipProbability ?? 0) >= 20 ? "\(h.precipProbability!)%" : " ")
                    .eyebrow(isNow ? V3.inverse.opacity(0.6) : V3.mute, size: 6.5)
            case .sun(let date, let rising):
                Text(Fmt.time(in: tz).string(from: date)).eyebrow(.black.opacity(0.6), size: 7.5)
                Image(systemName: rising ? "sunrise.fill" : "sunset.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .frame(height: 20)
                Text(rising ? "Rise" : "Set")
                    .font(V3Font.condensed(20, .medium))
                    .foregroundStyle(.black)
                Text(" ").eyebrow(size: 6.5)
            }
        }
        .frame(width: 62)
        .frame(maxHeight: .infinity)
        .background(fill)
        .hairline(.trailing)
        .onHover { hover = $0 }
    }

    private var fill: Color {
        switch item {
        case .hour(_, true): V3.ink
        case .sun: V3.signal
        default: hover ? V3.paperSoft : V3.paper
        }
    }
}
