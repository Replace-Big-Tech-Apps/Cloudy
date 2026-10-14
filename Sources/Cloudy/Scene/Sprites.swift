import SwiftUI
import CoreGraphics

/// Procedurally painted textures (clouds, fog banks, soft dots), generated once
/// with Core Graphics and cached. Soft radial "puffs" stack into volume, so no
/// per-frame blur is ever needed.
final class SpriteBank {
    static let shared = SpriteBank()

    static let cloudVariants = 6
    /// Cloud sprite size in points (rendered at 2×).
    static let cloudSize = CGSize(width: 520, height: 260)
    static let fogSize = CGSize(width: 1024, height: 220)

    private var cloudCache: [Int: Image] = [:]
    private var fogCache: [Int: Image] = [:]
    lazy var softDot: Image = Image(decorative: Self.makeSoftDot(), scale: 2)

    func cloud(_ variant: Int, tone: CloudTone) -> Image {
        let key = tone.rawValue * 100 + variant % Self.cloudVariants
        if let img = cloudCache[key] { return img }
        let img = Image(decorative: Self.makeCloud(variant: variant % Self.cloudVariants, tone: tone), scale: 2)
        cloudCache[key] = img
        return img
    }

    func fog(_ variant: Int, dark: Bool) -> Image {
        let key = (dark ? 10 : 0) + variant % 3
        if let img = fogCache[key] { return img }
        let img = Image(decorative: Self.makeFog(variant: variant % 3, dark: dark), scale: 2)
        fogCache[key] = img
        return img
    }

    // MARK: Painting

    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    private static func bitmap(_ w: Int, _ h: Int) -> CGContext {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    private static func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
        (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let (r1, g1, b1) = rgb(a), (r2, g2, b2) = rgb(b)
        return (r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
    }

    private static func puff(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat,
                             _ color: (CGFloat, CGFloat, CGFloat), _ a: CGFloat) {
        let (red, green, blue) = color
        let colors = [
            CGColor(srgbRed: red, green: green, blue: blue, alpha: a),
            CGColor(srgbRed: red, green: green, blue: blue, alpha: a * 0.9),
            CGColor(srgbRed: red, green: green, blue: blue, alpha: a * 0.35),
            CGColor(srgbRed: red, green: green, blue: blue, alpha: 0),
        ] as CFArray
        let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 0.78, 1])!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
    }

    private static func makeCloud(variant: Int, tone: CloudTone) -> CGImage {
        let w = 1040, h = 520
        let ctx = bitmap(w, h)
        var rng = SeededRandom(seed: UInt64(variant + 1) &* 0x9E37_79B9_7F4A_7C15)
        let (top, bottom) = tone.colors
        let baseY: CGFloat = 395
        let height = 0.65 + rng.next() * 0.45
        let lean = (rng.next() - 0.5) * 0.5

        // Flat, shadowed base.
        for k in 0..<9 {
            let x = 170 + CGFloat(k) * 88 + (rng.next() - 0.5) * 30
            puff(ctx, CGPoint(x: x, y: baseY + 20), 78 + rng.next() * 20, mix(top, bottom, 0.95), 0.42)
        }
        // Billowing body, tallest in the middle.
        let count = 34
        for k in 0..<count {
            let u = CGFloat(k) / CGFloat(count - 1)
            let profile = sin(.pi * min(1, max(0, u + lean * (u - 0.5))))
            let x = 130 + u * 780 + (rng.next() - 0.5) * 60
            let r = 62 + profile * 128 * (0.7 + rng.next() * 0.45)
            let y = baseY - profile * 125 * height * (0.65 + rng.next() * 0.4) + (rng.next() - 0.5) * 24
            let shade = min(1, max(0, (y - 120) / 300))
            puff(ctx, CGPoint(x: x, y: y), r, mix(top, bottom, pow(shade, 1.15)), 0.5)
        }
        // Sunlit crowns.
        for _ in 0..<10 {
            let u = 0.25 + rng.next() * 0.5
            let profile = sin(.pi * u)
            let x = 130 + u * 780
            let y = baseY - profile * 150 * height - 10
            puff(ctx, CGPoint(x: x, y: y), 50 + rng.next() * 50, rgb(top), 0.32)
        }
        return ctx.makeImage()!
    }

    private static func makeFog(variant: Int, dark: Bool) -> CGImage {
        let w = 2048, h = 440
        let ctx = bitmap(w, h)
        var rng = SeededRandom(seed: UInt64(variant + 7) &* 0xBF58_476D_1CE4_E5B9)
        let color = rgb(dark ? 0x4A5566 : 0xD3DAE2)
        for _ in 0..<26 {
            let x = 200 + rng.next() * 1650
            let y = 200 + (rng.next() - 0.5) * 120
            ctx.saveGState()
            ctx.translateBy(x: x, y: y)
            ctx.scaleBy(x: 2.8 + rng.next() * 1.6, y: 1)
            puff(ctx, .zero, 90 + rng.next() * 60, color, 0.32)
            ctx.restoreGState()
        }
        return ctx.makeImage()!
    }

    private static func makeSoftDot() -> CGImage {
        let ctx = bitmap(64, 64)
        let colors = [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.45),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray
        let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.35, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                               endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        return ctx.makeImage()!
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEAD_BEEF : seed }

    /// Uniform in [0, 1).
    mutating func next() -> CGFloat {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return CGFloat(state >> 11) / CGFloat(1 << 53)
    }
}

/// Stateless hash → [0, 1). Particles derive everything from (index, salt, time),
/// so the whole sky is a pure function of the clock.
@inline(__always)
func rnd(_ i: Int, _ salt: Int) -> Double {
    var x = UInt64(bitPattern: Int64(i &* 0x2545F491 &+ salt &* 0x9E3779B1 &+ 0x632BE5AB))
    x ^= x >> 33
    x &*= 0xFF51_AFD7_ED55_8CCD
    x ^= x >> 33
    x &*= 0xC4CE_B9FE_1A85_EC53
    x ^= x >> 33
    return Double(x >> 11) / Double(1 << 53)
}

@inline(__always)
func frac(_ x: Double) -> Double { x - floor(x) }
