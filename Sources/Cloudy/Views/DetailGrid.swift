import SwiftUI

/// Wind, humidity, UV, sun, pressure and visibility as one card of hairline-divided cells.
struct DetailGrid: View {
    @EnvironmentObject private var store: WeatherStore

    var body: some View {
        WidgetCard(eyebrow: "Conditions", title: "Right now", status: store.forecast?.timeZone.identifier ?? "") {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                if let f = store.forecast {
                    let unit = store.unit
                    GridRow {
                        WindCard(current: f.current, unit: unit)
                        HumidityCard(current: f.current, unit: unit)
                        UVCard(uv: f.current.uvIndex ?? 0, max: f.today?.uvMax)
                    }
                    GridRow {
                        SunCard(today: f.today, tz: f.timeZone)
                        PressureCard(hpa: f.current.pressure ?? 1013)
                        VisibilityCard(meters: f.current.visibility, unit: unit)
                    }
                } else {
                    ForEach(0..<2, id: \.self) { _ in
                        GridRow {
                            ForEach(0..<3, id: \.self) { _ in
                                ShimmerBar().padding(16).frame(maxWidth: .infinity).frame(height: 92)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 60 + 92 * 2)
    }
}

/// Shared cell chrome: eyebrow, big condensed value, mono footnote, optional accessory.
private struct DetailCard<Accessory: View>: View {
    let title: String
    let value: String
    var unit: String = ""
    let footnote: String
    @ViewBuilder var accessory: Accessory
    @State private var hover = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).eyebrow(V3.mute, size: 7.5)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(V3Font.condensed(30))
                        .foregroundStyle(V3.ink)
                        .contentTransition(.numericText())
                    if !unit.isEmpty { Text(unit).eyebrow(V3.mute, size: 7.5) }
                }
                Text(footnote)
                    .eyebrow(V3.whisper, size: 6.5)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            accessory
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
        .background(hover ? V3.paperSoft : V3.paper)
        .hairline([.bottom, .trailing])
        .onHover { h in withAnimation(V3.Motion.fast) { hover = h } }
    }
}

// MARK: Cards

private struct WindCard: View {
    let current: Forecast.Current
    let unit: TempUnit

    var body: some View {
        let w = unit.wind(current.windSpeed)
        DetailCard(title: "Wind", value: w.value, unit: w.unit,
                   footnote: "From \(Fmt.compass(current.windDirection))" + (current.windGusts.map { " · gusts \(unit.wind($0).value)" } ?? "")) {
            Compass(direction: current.windDirection, speed: current.windSpeed)
                .frame(width: 58, height: 58)
        }
    }
}

private struct Compass: View {
    let direction: Double
    let speed: Double
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().strokeBorder(V3.lineStrong)
            ForEach(0..<36, id: \.self) { i in
                Rectangle()
                    .fill(i % 9 == 0 ? V3.ink : V3.whisper)
                    .frame(width: 1, height: i % 9 == 0 ? 5 : 3)
                    .offset(y: -26)
                    .rotationEffect(.degrees(Double(i) * 10))
            }
            Text("N").font(V3Font.mono(7, .bold)).foregroundStyle(V3.ink).offset(y: -17)
            // The needle points where the wind is blowing to.
            Needle()
                .rotationEffect(.degrees((shown ? direction : direction - 120) + 180))
                .animation(.spring(response: 1.2, dampingFraction: 0.55), value: shown)
                .animation(.spring(response: 1.2, dampingFraction: 0.55), value: direction)
                .phaseAnimator([0.0, 1.0]) { v, p in
                    // gentle flutter that grows with wind speed
                    v.rotationEffect(.degrees((p - 0.5) * min(14, speed / 4)))
                } animation: { _ in .easeInOut(duration: 0.8) }
        }
        .onAppear { shown = true }
    }
}

/// Ink tail, yellow head with a black edge.
private struct Needle: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(V3.signal).overlay(Rectangle().strokeBorder(.black, lineWidth: 1)).frame(width: 5, height: 14)
            Rectangle().fill(V3.ink).frame(width: 2, height: 12)
        }
        .offset(y: -1)
    }
}

private struct HumidityCard: View {
    let current: Forecast.Current
    let unit: TempUnit

    var body: some View {
        DetailCard(title: "Humidity", value: "\(Int(current.humidity.rounded()))", unit: "%",
                   footnote: current.dewPoint.map { "Dew point \(unit.temp($0))°" } ?? " ") {
            Level(fraction: current.humidity / 100)
                .frame(width: 14, height: 60)
        }
    }
}

/// A square-cornered fill gauge.
private struct Level: View {
    let fraction: Double
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(V3.paperSoft)
            Rectangle()
                .fill(V3.ink)
                .frame(height: 60 * (shown ? max(0.06, fraction) : 0.02))
        }
        .overlay(Rectangle().strokeBorder(V3.lineStrong))
        .onAppear { withAnimation(.spring(duration: 1.1).delay(0.15)) { shown = true } }
    }
}

private struct UVCard: View {
    let uv: Double
    let max: Double?

    private var level: String {
        switch uv {
        case ..<3: "Low"
        case ..<6: "Moderate"
        case ..<8: "High"
        case ..<11: "Very high"
        default: "Extreme"
        }
    }

    var body: some View {
        DetailCard(title: "UV Index", value: String(format: uv < 10 ? "%.1f" : "%.0f", uv),
                   footnote: level + (max.map { " · peak \(Int($0.rounded()))" } ?? "")) {
            // One block per UV step; the current one is yellow.
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...11, id: \.self) { i in
                    let current = Int(uv.rounded()) == i || (i == 11 && uv >= 11)
                    Rectangle()
                        .fill(current ? V3.signal : (Double(i) <= uv ? V3.ink : V3.line))
                        .overlay(Rectangle().strokeBorder(current ? Color.black : .clear, lineWidth: 1))
                        .frame(width: 4, height: 8 + CGFloat(i) * 3)
                }
            }
            .frame(height: 44, alignment: .bottom)
        }
    }
}

private struct SunCard: View {
    let today: Forecast.Day?
    let tz: TimeZone

    var body: some View {
        let rise = today?.sunrise, set = today?.sunset
        let progress: Double? = {
            guard let rise, let set, set > rise else { return nil }
            return (Date.now.timeIntervalSince(rise) / set.timeIntervalSince(rise))
        }()
        let fmt = Fmt.time(in: tz)
        let isUp = progress.map { (0...1).contains($0) } ?? false
        DetailCard(title: isUp ? "Sunset" : "Sunrise",
                   value: (isUp ? set : rise).map(fmt.string(from:)) ?? "—",
                   footnote: isUp ? "Rose at \(rise.map(fmt.string(from:)) ?? "—")" : "Sets at \(set.map(fmt.string(from:)) ?? "—")") {
            SunArc(progress: progress ?? -1)
                .frame(width: 74, height: 40)
        }
    }
}

private struct SunArc: View {
    let progress: Double
    @State private var shown = false

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height - 2)
            let r = min(size.width / 2, size.height) - 4
            var arc = Path()
            arc.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(arc, with: .color(V3.whisper), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: center.y))
            horizon.addLine(to: CGPoint(x: size.width, y: center.y))
            ctx.stroke(horizon, with: .color(V3.ink), lineWidth: 1)

            guard (0...1).contains(progress) else { return }
            let p = shown ? progress : 0
            var lit = Path()
            lit.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * p), clockwise: false)
            ctx.stroke(lit, with: .color(V3.ink), lineWidth: 1.5)
            let a = Double.pi * (1 + p)
            let sun = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            let disc = Path(ellipseIn: CGRect(x: sun.x - 5, y: sun.y - 5, width: 10, height: 10))
            ctx.fill(disc, with: .color(V3.signal))
            ctx.stroke(disc, with: .color(.black), lineWidth: 1)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { shown = true } }
        .animation(.easeOut(duration: 1.2), value: shown)
    }
}

private struct PressureCard: View {
    let hpa: Double

    var body: some View {
        DetailCard(title: "Pressure", value: "\(Int(hpa.rounded()))", unit: "hPa",
                   footnote: hpa < 1000 ? "Low · unsettled" : (hpa > 1022 ? "High · settled" : "Normal")) {
            Gauge(fraction: (hpa - 970) / 80)
                .frame(width: 58, height: 58)
        }
    }
}

private struct Gauge: View {
    let fraction: Double
    @State private var shown = false

    var body: some View {
        let f = min(1, max(0, fraction))
        ZStack {
            ForEach(0...20, id: \.self) { i in
                Rectangle()
                    .fill(Double(i) / 20 <= (shown ? f : 0) ? V3.ink : V3.line)
                    .frame(width: 1.5, height: i % 5 == 0 ? 7 : 4)
                    .offset(y: -23)
                    .rotationEffect(.degrees(-135 + 270 * Double(i) / 20))
            }
            Rectangle()
                .fill(V3.signal)
                .overlay(Rectangle().strokeBorder(.black, lineWidth: 1))
                .frame(width: 4, height: 20)
                .offset(y: -10)
                .rotationEffect(.degrees(-135 + 270 * (shown ? f : 0)))
            Rectangle().fill(V3.ink).frame(width: 6, height: 6)
        }
        .onAppear { withAnimation(.spring(response: 1.3, dampingFraction: 0.6).delay(0.1)) { shown = true } }
    }
}

private struct VisibilityCard: View {
    let meters: Double?
    let unit: TempUnit

    var body: some View {
        let m = meters ?? 10_000
        let d = unit.distance(m)
        let note = switch m {
        case ..<1000: "Fog · very poor"
        case ..<4000: "Mist or haze"
        case ..<10_000: "Moderate"
        default: "Clear view"
        }
        DetailCard(title: "Visibility", value: d.value, unit: d.unit, footnote: note) {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(Double(i) / 5 < min(1, m / 24_000) ? V3.ink : V3.line)
                        .frame(width: 34 - CGFloat(i) * 5, height: 3)
                }
            }
        }
    }
}
