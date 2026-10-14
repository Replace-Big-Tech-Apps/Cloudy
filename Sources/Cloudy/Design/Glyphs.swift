import SwiftUI

/// SF Symbol in ink, with the yellow signal for sun, moon and lightning.
struct WeatherGlyph: View {
    let kind: WeatherKind
    let isDay: Bool
    var size: CGFloat = 16
    var ink: Color = V3.ink
    var accent: Color = V3.signal

    var body: some View {
        let symbol = Image(systemName: kind.symbol(isDay: isDay)).font(.system(size: size))
        switch kind {
        case .clear, .mostlyClear:
            symbol.foregroundStyle(isDay ? accent : ink)
        case .partlyCloudy:
            symbol.symbolRenderingMode(.palette).foregroundStyle(ink, isDay ? accent : ink.opacity(0.55))
        case .thunderstorm:
            symbol.symbolRenderingMode(.palette).foregroundStyle(ink, accent)
        default:
            symbol.symbolRenderingMode(.palette).foregroundStyle(ink, ink.opacity(0.45))
        }
    }
}

/// Temperature range: a square-ended ink bar on a hairline track, with a yellow
/// marker for the current temperature.
struct TempRangeBar: View {
    let low: Double
    let high: Double
    let range: ClosedRange<Double>
    var now: Double?
    var ink: Color = V3.ink
    var track: Color = V3.line

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let x0 = (low - range.lowerBound) / span * geo.size.width
            let x1 = (high - range.lowerBound) / span * geo.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle()
                    .fill(ink)
                    .frame(width: max(4, x1 - x0))
                    .offset(x: x0)
                if let now {
                    let xn = (min(max(now, low), high) - range.lowerBound) / span * geo.size.width
                    Rectangle()
                        .fill(V3.signal)
                        .overlay(Rectangle().strokeBorder(.black, lineWidth: 1))
                        .frame(width: 7, height: geo.size.height + 5)
                        .offset(x: xn - 3.5)
                }
            }
        }
    }
}
