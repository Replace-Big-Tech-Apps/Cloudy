import SwiftUI

enum SceneClock {
    static let start = Date()
}

/// Eases the pointer-driven parallax so the sky drifts rather than snaps.
final class ParallaxDriver {
    var target: CGSize = .zero
    private var value: CGSize = .zero
    private var last: Double?

    func step(_ t: Double) -> CGSize {
        if let last, t > last {
            let k = 1 - exp(-(t - last) * 2.5)
            value.width += (target.width - value.width) * k
            value.height += (target.height - value.height) * k
        }
        last = t
        return value
    }
}

/// One animated sky, redrawn every display frame.
struct WeatherScene: View {
    let config: SceneConfig
    let parallax: ParallaxDriver
    var paused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused)) { timeline in
            Canvas(rendersAsynchronously: false) { ctx, size in
                let t = timeline.date.timeIntervalSince(SceneClock.start) * (reduceMotion ? 0.3 : 1)
                SceneRenderer(c: config, t: t, size: size, px: parallax.step(t)).draw(&ctx)
            }
        }
    }
}

/// Cross-fades between skies whenever the weather (or day/night) changes.
struct WeatherBackdrop: View {
    let config: SceneConfig
    let parallax: ParallaxDriver

    var body: some View {
        ZStack {
            WeatherScene(config: config, parallax: parallax)
                .id(config.identity)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 1.6), value: config.identity)
        .background(V3.night)
    }
}
