import SwiftUI
import AppKit

/// `Cloudy --gallery <dir> [t]` renders every sky (day + night) to PNG and exits.
/// Handy for eyeballing the scenes and for README screenshots.
enum Gallery {
    @MainActor
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--gallery"), args.indices.contains(i + 1) else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        let t = args.indices.contains(i + 2) ? Double(args[i + 2]) ?? 14.2 : 14.2
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for kind in WeatherKind.allCases {
            for isDay in [true, false] {
                let config = SceneConfig.make(kind: kind, isDay: isDay, windKmh: nil)
                // Storms: jump to a moment mid-flash so the bolt shows up.
                let frameT = config.lightning > 0 ? flashTime(config, near: t) : t
                let view = Canvas { ctx, size in
                    SceneRenderer(c: config, t: frameT, size: size, px: .zero).draw(&ctx)
                }
                .frame(width: 960, height: 600)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                guard let cg = renderer.cgImage else { continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                let url = dir.appendingPathComponent("\(kind.rawValue)-\(isDay ? "day" : "night").png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
        print("Gallery written to \(dir.path)")
        exit(0)
    }

    private static func flashTime(_ config: SceneConfig, near t: Double) -> Double {
        let slot = 5.2 / max(0.4, config.lightning)
        var k = Int(floor(t / slot))
        while rnd(k, 152) <= 0.25 { k += 1 }
        return Double(k) * slot + rnd(k, 151) * slot * 0.55 + 0.02
    }
}
