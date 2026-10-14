import SwiftUI

/// Paints one frame of a sky. Pure function of (config, time, size, parallax).
struct SceneRenderer {
    let c: SceneConfig
    let t: Double
    let size: CGSize
    /// Smoothed pointer offset in −1…1, used for depth parallax.
    let px: CGSize

    private var W: Double { size.width }
    private var H: Double { size.height }
    private var sprites: SpriteBank { .shared }

    private var celestialCenter: CGPoint {
        CGPoint(x: W * 0.57 - px.width * 9, y: H * 0.21 - px.height * 7)
    }

    func draw(_ ctx: inout GraphicsContext) {
        drawSky(&ctx)
        if c.stars > 0 { drawStars(&ctx) }
        if c.celestial > 0 { c.isDay ? drawSun(&ctx) : drawMoon(&ctx) }
        if c.deck > 0 { drawDeck(&ctx) }

        let flash = c.lightning > 0 ? lightning() : nil

        drawClouds(&ctx, layer: 0)
        drawClouds(&ctx, layer: 1)
        if let flash, flash.bolt { drawBolt(&ctx, flash) }
        drawClouds(&ctx, layer: 2)

        if c.motes > 0 { drawMotes(&ctx) }
        if c.fog > 0 { drawFog(&ctx) }
        if c.rain > 0 { drawRain(&ctx) }
        if c.ice > 0 { drawIce(&ctx) }
        if c.hail > 0 { drawHail(&ctx) }
        if c.snow > 0 { drawSnow(&ctx) }
        if c.windStreaks > 0 { drawWindStreaks(&ctx) }
        if c.leaves > 0 { drawLeaves(&ctx) }
        if c.frost > 0 { drawFrost(&ctx) }
        if let flash { drawFlash(&ctx, flash) }
    }

    // MARK: - Sky

    private func drawSky(_ ctx: inout GraphicsContext) {
        let rect = CGRect(origin: .zero, size: size)
        let stops = c.sky.enumerated().map {
            Gradient.Stop(color: Color(hex: $0.element), location: Double($0.offset) / Double(max(1, c.sky.count - 1)))
        }
        ctx.fill(Path(rect), with: .linearGradient(Gradient(stops: stops), startPoint: .zero,
                                                   endPoint: CGPoint(x: 0, y: H)))
        // Warm horizon glow under a visible sun.
        if c.isDay && c.celestial > 0.5 {
            let g = Gradient(colors: [Color(hex: 0xC9A84C, alpha: 0.16 * c.celestial), .clear])
            ctx.fill(Path(rect), with: .radialGradient(g, center: CGPoint(x: celestialCenter.x, y: H * 1.05),
                                                       startRadius: 0, endRadius: H * 0.9))
        }
    }

    // MARK: - Night sky

    private func drawStars(_ ctx: inout GraphicsContext) {
        let shift = CGSize(width: -px.width * 4, height: -px.height * 4)
        if c.milkyWay {
            var band = ctx
            band.opacity = 0.09 * c.stars
            band.translateBy(x: W * 0.5 + shift.width, y: H * 0.32 + shift.height)
            band.rotate(by: .degrees(-24))
            band.draw(sprites.fog(1, dark: false), in: CGRect(x: -W * 0.85, y: -H * 0.16, width: W * 1.7, height: H * 0.32))
            for i in 0..<260 {
                let along = (rnd(i, 71) - 0.5) * W * 1.6
                let across = (rnd(i, 72) + rnd(i, 73) - 1) * H * 0.12
                let r = 0.3 + rnd(i, 74) * 0.7
                band.opacity = (0.3 + 0.7 * rnd(i, 75)) * c.stars
                band.fill(Path(ellipseIn: CGRect(x: along - r, y: across - r, width: r * 2, height: r * 2)), with: .color(.white))
            }
        }

        let n = Int(240 * c.stars)
        for i in 0..<n {
            let x = rnd(i, 1) * W + shift.width
            let y = pow(rnd(i, 2), 1.35) * H * 0.82 + shift.height
            let r = 0.35 + pow(rnd(i, 3), 3) * 1.6
            let twinkle = 0.55 + 0.45 * sin(t * (0.5 + rnd(i, 4) * 2.4) + rnd(i, 5) * 6.283)
            let a = (0.25 + 0.75 * rnd(i, 6)) * twinkle * c.stars
            let tint = rnd(i, 7) < 0.15 ? Color(hex: 0xDFD2BC) : (rnd(i, 7) > 0.9 ? Color(hex: 0xC8D8F5) : .white)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(a)))
            if r > 1.3 {
                var glow = ctx
                glow.opacity = a * 0.5
                glow.draw(sprites.softDot, in: CGRect(x: x - r * 4, y: y - r * 4, width: r * 8, height: r * 8))
            }
        }

        // Shooting stars.
        let slot = 6.5
        let k = Int(floor(t / slot))
        let local = t - Double(k) * slot
        if rnd(k, 81) < 0.55 && local < 1.0 {
            let p = local / 1.0
            let start = CGPoint(x: W * (0.25 + rnd(k, 82) * 0.65), y: H * (0.04 + rnd(k, 83) * 0.25))
            let dir = CGVector(dx: -0.86, dy: 0.5)
            let travel = 260 + rnd(k, 84) * 220
            let head = CGPoint(x: start.x + dir.dx * travel * p, y: start.y + dir.dy * travel * p)
            let tailLen = 120 * sin(.pi * p)
            let tail = CGPoint(x: head.x - dir.dx * tailLen, y: head.y - dir.dy * tailLen)
            var line = Path()
            line.move(to: tail)
            line.addLine(to: head)
            let fade = sin(.pi * p) * c.stars
            ctx.stroke(line, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.9 * fade)]),
                                                   startPoint: tail, endPoint: head),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            var glow = ctx
            glow.opacity = fade
            glow.draw(sprites.softDot, in: CGRect(x: head.x - 5, y: head.y - 5, width: 10, height: 10))
        }
    }

    // MARK: - Sun & moon

    private func drawSun(_ ctx: inout GraphicsContext) {
        let v = c.celestial
        let o = celestialCenter
        let breathe = 1 + 0.03 * sin(t * 0.8)

        let halo = Gradient(stops: [
            .init(color: Color(hex: 0xF3D78A, alpha: 0.42 * v), location: 0),
            .init(color: Color(hex: 0xC9A84C, alpha: 0.14 * v), location: 0.35),
            .init(color: .clear, location: 1),
        ])
        let haloR = 330 * breathe
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - haloR, y: o.y - haloR, width: haloR * 2, height: haloR * 2)),
                 with: .radialGradient(halo, center: o, startRadius: 0, endRadius: haloR))

        // Soft, slowly turning god-rays — only when the sun is properly out.
        let rayStrength = max(0, (v - 0.5) * 2)
        if rayStrength > 0 {
            var rays = ctx
            rays.translateBy(x: o.x, y: o.y)
            rays.rotate(by: .radians(t * 0.02))
            rays.blendMode = .plusLighter
            for k in 0..<12 {
                let base = Double(k) / 12 * 2 * .pi + rnd(k, 91) * 0.3
                let len = (190 + rnd(k, 92) * 170) * (0.85 + 0.15 * sin(t * (0.3 + rnd(k, 93) * 0.4) + Double(k)))
                let spread = 0.05 + rnd(k, 94) * 0.06
                var p = Path()
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: cos(base - spread) * len, y: sin(base - spread) * len))
                p.addLine(to: CGPoint(x: cos(base + spread) * len, y: sin(base + spread) * len))
                p.closeSubpath()
                let a = (0.05 + 0.04 * sin(t * 0.5 + Double(k) * 1.7)) * rayStrength
                rays.fill(p, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF1CC, alpha: a), .clear]),
                                                   center: .zero, startRadius: 30, endRadius: len))
            }
        }

        // Disc.
        let r = 44.0
        let disc = Gradient(stops: [
            .init(color: Color(hex: 0xFFFBEF), location: 0),
            .init(color: Color(hex: 0xF7E2A6), location: 0.6),
            .init(color: Color(hex: 0xE3BC5E), location: 1),
        ])
        var core = ctx
        core.opacity = min(1, pow(v, 1.4) * 1.2)
        core.fill(Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2)),
                  with: .radialGradient(disc, center: CGPoint(x: o.x - 10, y: o.y - 12), startRadius: 0, endRadius: r * 1.3))
        let ring = 64 + 6 * sin(t * 1.1)
        core.opacity = 0.14 * rayStrength
        core.stroke(Path(ellipseIn: CGRect(x: o.x - ring, y: o.y - ring, width: ring * 2, height: ring * 2)),
                    with: .color(Color(hex: 0xF3D78A)), lineWidth: 1)
    }

    private func drawMoon(_ ctx: inout GraphicsContext) {
        let v = c.celestial
        let o = celestialCenter
        let R = 34.0

        let halo = Gradient(stops: [
            .init(color: Color(hex: 0xCFD8E8, alpha: 0.2 * v), location: 0),
            .init(color: Color(hex: 0x6B89C4, alpha: 0.06 * v), location: 0.4),
            .init(color: .clear, location: 1),
        ])
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - 240, y: o.y - 240, width: 480, height: 480)),
                 with: .radialGradient(halo, center: o, startRadius: 0, endRadius: 240))

        var m = ctx
        m.translateBy(x: o.x, y: o.y)
        m.opacity = v
        let disc = Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2))
        m.fill(disc, with: .color(Color(hex: 0x1A2231, alpha: 0.9)))   // earthshine

        let lit = Self.moonPath(radius: R, phase: Self.moonPhase(.now))
        m.fill(lit, with: .radialGradient(Gradient(colors: [Color(hex: 0xF6F3EA), Color(hex: 0xD5D0C2)]),
                                          center: CGPoint(x: -8, y: -10), startRadius: 0, endRadius: R * 1.4))
        var craters = m
        craters.clip(to: lit)
        for (x, y, r) in [(-12.0, -8.0, 7.0), (9.0, 10.0, 5.5), (12.0, -14.0, 3.5), (-6.0, 15.0, 4.0), (2.0, -2.0, 2.5)] {
            craters.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(hex: 0x8A8778, alpha: 0.22)))
        }
        m.stroke(disc, with: .color(.white.opacity(0.06)), lineWidth: 1)
    }

    /// 0 = new, 0.5 = full.
    static func moonPhase(_ date: Date) -> Double {
        let reference = Date(timeIntervalSince1970: 947_182_440)  // 2000-01-06 18:14 UTC new moon
        return frac(date.timeIntervalSince(reference) / 86_400 / 29.530588853)
    }

    static func moonPath(radius R: Double, phase: Double) -> Path {
        let k = cos(phase * 2 * .pi)
        let s: Double = phase < 0.5 ? 1 : -1
        var p = Path()
        let steps = 48
        for j in 0...steps {
            let th = Double.pi * Double(j) / Double(steps)
            let pt = CGPoint(x: s * R * sin(th), y: -R * cos(th))
            j == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        for j in stride(from: steps, through: 0, by: -1) {
            let th = Double.pi * Double(j) / Double(steps)
            p.addLine(to: CGPoint(x: s * k * R * sin(th), y: -R * cos(th)))
        }
        p.closeSubpath()
        return p
    }

    // MARK: - Clouds

    private func drawDeck(_ ctx: inout GraphicsContext) {
        let tone = Color(hex: c.cloudTone.colors.bottom)
        let g = Gradient(stops: [
            .init(color: tone.opacity(0.95 * c.deck), location: 0),
            .init(color: tone.opacity(0.55 * c.deck), location: 0.3),
            .init(color: .clear, location: 0.7),
        ])
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(g, startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
    }

    private func drawClouds(_ ctx: inout GraphicsContext, layer: Int) {
        let cover = c.cloudCover
        guard cover > 0 else { return }
        let count: Int
        let scale: ClosedRange<Double>
        let alpha: Double
        let speed: Double
        let band: ClosedRange<Double>
        let depth: Double
        switch layer {
        case 0:
            count = Int((2 + cover * 8).rounded()); scale = 0.5...0.75; alpha = 0.55
            speed = 5; band = 0.0...0.34; depth = 10
        case 1:
            count = Int((cover * 7).rounded()); scale = 0.85...1.15; alpha = 0.82
            speed = 10; band = -0.04...0.4; depth = 20
        default:
            count = Int((cover * cover * 6).rounded()); scale = 1.3...1.85; alpha = 0.94
            speed = 18; band = -0.12...0.3; depth = 34
        }
        guard count > 0 else { return }
        let fit = min(1.6, max(0.85, W / 1200))
        for i in 0..<count {
            let seed = layer * 97 + i
            let s = (scale.lowerBound + rnd(seed, 11) * (scale.upperBound - scale.lowerBound)) * fit
            let w = SpriteBank.cloudSize.width * s
            let h = SpriteBank.cloudSize.height * s
            let v = speed * (0.7 + 0.6 * rnd(seed, 12)) * (1 + c.wind * 3) * c.cloudSpeed
            let span = W + w
            let phase = (Double(i) + rnd(seed, 13) * 0.7) / Double(count)
            let x = frac(phase + t * v / span) * span - w - px.width * depth
            let y = (band.lowerBound + rnd(seed, 14) * (band.upperBound - band.lowerBound)) * H
                + sin(t * 0.07 + Double(seed)) * 5 - px.height * depth * 0.6
            var l = ctx
            l.opacity = alpha * (0.75 + 0.25 * rnd(seed, 15))
            l.draw(sprites.cloud(seed, tone: c.cloudTone), in: CGRect(x: x, y: y, width: w, height: h))
        }
    }

    // MARK: - Light & air

    private func drawMotes(_ ctx: inout GraphicsContext) {
        var m = ctx
        m.blendMode = .plusLighter
        for i in 0..<28 {
            let x = frac(rnd(i, 61) + t * 0.006 * (0.4 + rnd(i, 62))) * W - px.width * 14
            let y = H * (0.2 + 0.75 * rnd(i, 63)) + sin(t * 0.35 + Double(i)) * 18 - px.height * 14
            let r = 0.8 + rnd(i, 64) * 2.2
            let a = (0.15 + 0.45 * rnd(i, 65)) * (0.5 + 0.5 * sin(t * (0.6 + rnd(i, 66)) + Double(i))) * c.motes
            m.opacity = a * 0.35
            m.draw(sprites.softDot, in: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6))
            m.opacity = a
            m.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)), with: .color(Color(hex: 0xF3D78A)))
        }
    }

    private func drawFog(_ ctx: inout GraphicsContext) {
        let dark = !c.isDay
        let bands = 7
        for i in 0..<bands {
            let u = Double(i) / Double(bands - 1)
            let w = W * 1.7
            let h = w * SpriteBank.fogSize.height / SpriteBank.fogSize.width * (1.2 + u)
            let drift = sin(t * (0.025 + 0.02 * rnd(i, 101)) * (1 + c.wind * 2) + Double(i) * 1.7) * W * 0.22
            let x = -w * 0.2 + drift - px.width * (8 + u * 20)
            let y = H * (0.3 + 0.68 * u) - h * 0.5
            var l = ctx
            l.opacity = c.fog * (0.4 + 0.45 * u)
            l.draw(sprites.fog(i, dark: dark), in: CGRect(x: x, y: y, width: w, height: h))
        }
        let haze = Color(hex: dark ? 0x3A4454 : 0xB9C3CE)
        let g = Gradient(colors: [.clear, haze.opacity(0.55 * c.fog)])
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(g, startPoint: CGPoint(x: 0, y: H * 0.25), endPoint: CGPoint(x: 0, y: H)))
    }

    // MARK: - Precipitation

    private var precipDim: Double { c.isDay ? 1 : 0.75 }

    private func drawRain(_ ctx: inout GraphicsContext) {
        let (count, lenRange, baseSpeed): (Double, ClosedRange<Double>, Double) = switch c.rainStyle {
        case .drizzle: (300, 7...13, 380)
        case .rain: (420, 18...32, 950)
        case .heavy: (760, 26...46, 1350)
        }
        let n = Int(count * c.rain * min(1.4, max(0.7, W / 1200)))
        let slant = 0.07 + c.wind * 0.5
        var paths = [Path(), Path(), Path()]
        for i in 0..<n {
            let d = rnd(i, 21)
            let len = (lenRange.lowerBound + (lenRange.upperBound - lenRange.lowerBound) * rnd(i, 22)) * (0.55 + 0.7 * d)
            let v = baseSpeed * (0.55 + 0.75 * d)
            let travel = H + len * 2
            let y = frac(rnd(i, 23) + t * v / travel) * travel - len
            let x0 = rnd(i, 24) * (W + H * slant) - H * slant
            let x = x0 + y * slant - px.width * (4 + d * 10)
            let b = min(2, Int(d * 3))
            paths[b].move(to: CGPoint(x: x, y: y))
            paths[b].addLine(to: CGPoint(x: x + len * slant, y: y + len))
        }
        let color = Color(hex: 0xC6D4E6)
        let alphas = [0.16, 0.3, 0.52]
        let widths = c.rainStyle == .drizzle ? [0.6, 0.8, 1.0] : [0.7, 1.0, 1.4]
        for b in 0..<3 {
            ctx.stroke(paths[b], with: .color(color.opacity(alphas[b] * precipDim)),
                       style: StrokeStyle(lineWidth: widths[b], lineCap: .round))
        }

        // Splashes on the ground plane.
        guard c.rainStyle != .drizzle else { return }
        let splashes = Int(Double(c.rainStyle == .heavy ? 70 : 40) * c.rain)
        var rings = [Path(), Path(), Path()]
        for i in 0..<splashes {
            let period = 0.45 + rnd(i, 31) * 0.45
            let raw = t / period + rnd(i, 32)
            let cycle = Int(floor(raw))
            let p = frac(raw)
            let x = rnd(i &* 977 &+ cycle, 33) * W
            let y = H * (0.88 + 0.11 * rnd(i &* 977 &+ cycle, 34))
            let r = 1.5 + p * (6 + 5 * rnd(i, 35))
            let b = min(2, Int(p * 3))
            rings[b].addEllipse(in: CGRect(x: x - r, y: y - r * 0.28, width: r * 2, height: r * 0.56))
            if p < 0.35 {
                // little droplet kicked up
                let up = sin(p / 0.35 * .pi) * 7
                rings[0].addEllipse(in: CGRect(x: x - 0.8 + r * 0.6, y: y - up - 0.8, width: 1.6, height: 1.6))
            }
        }
        let ringAlpha = [0.38, 0.22, 0.08]
        for b in 0..<3 {
            ctx.stroke(rings[b], with: .color(color.opacity(ringAlpha[b] * precipDim)), lineWidth: 0.8)
        }
    }

    private func drawIce(_ ctx: inout GraphicsContext) {
        let n = Int(170 * c.ice)
        let slant = 0.06 + c.wind * 0.4
        var path = Path()
        for i in 0..<n {
            let d = rnd(i, 111)
            let v = 600 + 420 * d
            let y = frac(rnd(i, 112) + t * v / (H + 20)) * (H + 20) - 10
            let x = rnd(i, 113) * (W + H * slant) - H * slant + y * slant - px.width * 8
            let r = 1.0 + d * 1.4
            path.addRoundedRect(in: CGRect(x: x - r / 2, y: y, width: r, height: r * 3.2),
                                cornerSize: CGSize(width: r / 2, height: r / 2))
        }
        ctx.fill(path, with: .color(Color(hex: 0xEAF3FF, alpha: 0.75 * precipDim)))
    }

    private func drawHail(_ ctx: inout GraphicsContext) {
        let n = Int(110 * c.hail)
        var stones = Path()
        var glints = Path()
        for i in 0..<n {
            let d = rnd(i, 121)
            let r = 1.8 + d * 2.8
            let v = 820 + 520 * d
            let ground = H * (0.84 + 0.14 * rnd(i, 122))
            let fall = (ground + 20) / v
            let bounceT = 0.38 + 0.2 * rnd(i, 123)
            let period = fall + bounceT
            let raw = t / period + rnd(i, 124)
            let cycle = Int(floor(raw))
            let local = frac(raw) * period
            var x = rnd(i &* 131 &+ cycle, 125) * W - px.width * 8
            let y: Double
            var a = 1.0
            if local < fall {
                y = -20 + v * local
                x += (y + 20) * c.wind * 0.25
            } else {
                let b = (local - fall) / bounceT
                let hop = 18 + 34 * rnd(i, 126)
                y = ground - 4 * hop * b * (1 - b)
                x += (ground + 20) * c.wind * 0.25 + b * (rnd(i, 127) - 0.5) * 50
                a = 1 - b * 0.8
            }
            if a < 0.5 { continue }
            stones.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            glints.addEllipse(in: CGRect(x: x - r * 0.45, y: y - r * 0.55, width: r * 0.6, height: r * 0.6))
        }
        ctx.fill(stones, with: .color(Color(hex: 0xDCE6F2, alpha: 0.82 * precipDim)))
        ctx.fill(glints, with: .color(.white.opacity(0.9)))
        // Fallen hail glittering on the ground.
        var floor = Path()
        for i in 0..<Int(90 * c.hail) {
            let x = rnd(i, 128) * W
            let y = H * (0.9 + 0.1 * rnd(i, 129))
            let r = 1 + rnd(i, 130) * 1.6
            floor.addEllipse(in: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2))
        }
        ctx.fill(floor, with: .color(Color(hex: 0xDCE6F2, alpha: 0.35)))
    }

    private func drawSnow(_ ctx: inout GraphicsContext) {
        let n = Int((c.blizzard ? 560 : 260) * c.snow * min(1.4, max(0.7, W / 1200)))
        let drift = c.blizzard ? 1.1 : 0.08 + c.wind * 0.35
        var small = Path()
        var faint = Path()
        var big = ctx
        for i in 0..<n {
            let d = rnd(i, 41)
            let r = c.blizzard ? 0.7 + d * 2.0 : 0.9 + d * 2.8
            let v = c.blizzard ? 110 + d * 220 : 26 + d * 58
            let travel = H + 30
            let y = frac(rnd(i, 42) + t * v / travel) * travel - 15
            let sway = sin(t * (0.35 + rnd(i, 43) * 0.9) + rnd(i, 44) * 6.28) * (6 + 22 * d) * (c.blizzard ? 0.4 : 1)
            let x = frac(rnd(i, 45) + (y * drift + sway - px.width * (6 + d * 18)) / W) * W
            if d > 0.78 {
                big.opacity = (0.55 + 0.4 * d) * precipDim
                big.draw(sprites.softDot, in: CGRect(x: x - r * 2.4, y: y - r * 2.4, width: r * 4.8, height: r * 4.8))
            } else if d > 0.35 {
                small.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            } else {
                faint.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
        ctx.fill(small, with: .color(.white.opacity(0.75 * precipDim)))
        ctx.fill(faint, with: .color(.white.opacity(0.4 * precipDim)))

        // Snow settling along the bottom edge.
        let bank = Gradient(colors: [.clear, Color(hex: 0xE8EEF5, alpha: (c.blizzard ? 0.22 : 0.14) * c.snow)])
        ctx.fill(Path(CGRect(x: 0, y: H * 0.82, width: W, height: H * 0.18)),
                 with: .linearGradient(bank, startPoint: CGPoint(x: 0, y: H * 0.82), endPoint: CGPoint(x: 0, y: H)))
    }

    // MARK: - Wind

    private func drawWindStreaks(_ ctx: inout GraphicsContext) {
        let n = Int(24 * c.windStreaks)
        for i in 0..<n {
            let L = 160 + rnd(i, 51) * 280
            let v = 420 + rnd(i, 52) * 520
            let span = W + L * 2
            let head = frac(rnd(i, 53) + t * v / span) * span - L
            let baseY = (0.08 + rnd(i, 54) * 0.84) * H - px.height * 12
            let wobble = rnd(i, 55) * 6.28
            var p = Path()
            for s in 0...28 {
                let u = Double(s) / 28
                let x = head - u * L
                let y = baseY + sin(x * 0.011 + wobble + t * 1.3) * 11
                    + (u > 0.7 ? sin((u - 0.7) * 10) * 9 * rnd(i, 56) : 0)   // curl at the tail
                s == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
            }
            let a = (0.12 + 0.18 * rnd(i, 57)) * c.windStreaks
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [.white.opacity(a), .clear]),
                                                startPoint: CGPoint(x: head, y: baseY),
                                                endPoint: CGPoint(x: head - L, y: baseY)),
                       style: StrokeStyle(lineWidth: 1 + rnd(i, 58) * 0.8, lineCap: .round))
        }
    }

    private func drawLeaves(_ ctx: inout GraphicsContext) {
        let palette: [UInt32] = [0xC9A84C, 0xE09A3A, 0xA8803A, 0xDFD2BC]
        for i in 0..<Int(11 * c.leaves) {
            let v = 170 + rnd(i, 141) * 230
            let span = W + 120
            let x = frac(rnd(i, 142) + t * v / span) * span - 60
            let y = H * (0.25 + 0.65 * rnd(i, 143)) + sin(t * (1 + rnd(i, 144)) + Double(i)) * 46 + x * 0.06
            var l = ctx
            l.translateBy(x: x, y: y)
            l.rotate(by: .radians(t * (1.5 + rnd(i, 145) * 3) + Double(i)))
            l.scaleBy(x: max(0.15, abs(cos(t * (2 + rnd(i, 146) * 2) + Double(i)))), y: 1)
            let s = 5 + rnd(i, 147) * 4
            var leaf = Path()
            leaf.move(to: CGPoint(x: -s * 1.6, y: 0))
            leaf.addQuadCurve(to: CGPoint(x: s * 1.6, y: 0), control: CGPoint(x: 0, y: -s * 1.2))
            leaf.addQuadCurve(to: CGPoint(x: -s * 1.6, y: 0), control: CGPoint(x: 0, y: s * 1.2))
            l.opacity = c.isDay ? 0.85 : 0.5
            l.fill(leaf, with: .color(Color(hex: palette[i % palette.count])))
            var vein = Path()
            vein.move(to: CGPoint(x: -s * 1.4, y: 0))
            vein.addLine(to: CGPoint(x: s * 1.4, y: 0))
            l.stroke(vein, with: .color(.black.opacity(0.25)), lineWidth: 0.6)
        }
    }

    // MARK: - Frost

    private func drawFrost(_ ctx: inout GraphicsContext) {
        let shimmer = 0.85 + 0.15 * sin(t * 0.9)
        let ice = Color(hex: 0xDCEBFF)
        for corner in [CGPoint.zero, CGPoint(x: W, y: 0), CGPoint(x: 0, y: H), CGPoint(x: W, y: H)] {
            let g = Gradient(stops: [.init(color: ice.opacity(0.26 * c.frost), location: 0),
                                     .init(color: ice.opacity(0.08 * c.frost), location: 0.5),
                                     .init(color: .clear, location: 1)])
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(g, center: corner, startRadius: 0, endRadius: min(W, H) * 0.45))
        }
        ctx.stroke(FrostCache.path(for: size), with: .color(ice.opacity(0.13 * c.frost * shimmer)), lineWidth: 0.6)
    }

    // MARK: - Lightning

    struct Flash {
        var intensity: Double
        var bolt: Bool
        var seed: Int
        var x: Double
    }

    private func lightning() -> Flash? {
        let slot = 5.2 / max(0.4, c.lightning)
        let k = Int(floor(t / slot))
        let start = rnd(k, 151) * slot * 0.55
        let d = t - Double(k) * slot - start
        guard d >= 0, d < 0.75 else { return nil }
        var intensity = 0.0
        for (offset, amp) in [(0.0, 1.0), (0.09, 0.5), (0.21, 0.85), (0.36, 0.3)] where d >= offset {
            intensity = max(intensity, amp * exp(-(d - offset) * 13))
        }
        return Flash(intensity: intensity * c.lightning, bolt: rnd(k, 152) > 0.25, seed: k,
                     x: 0.12 + rnd(k, 153) * 0.76)
    }

    private func drawBolt(_ ctx: inout GraphicsContext, _ f: Flash) {
        var main = Path()
        var branches = Path()
        var pt = CGPoint(x: W * f.x, y: H * 0.1)
        let endY = H * (0.72 + 0.2 * rnd(f.seed, 154))
        main.move(to: pt)
        var j = 0
        while pt.y < endY && j < 80 {
            j += 1
            let s = f.seed &* 131 &+ j
            pt = CGPoint(x: pt.x + (rnd(s, 1) - 0.5) * 46, y: pt.y + 12 + rnd(s, 2) * 26)
            main.addLine(to: pt)
            if rnd(s, 3) < 0.2 {
                var b = pt
                let dir: Double = rnd(s, 4) < 0.5 ? -1 : 1
                branches.move(to: b)
                for m in 0..<(3 + Int(rnd(s, 5) * 5)) {
                    b = CGPoint(x: b.x + dir * (8 + rnd(s &+ m, 6) * 22), y: b.y + 8 + rnd(s &+ m, 7) * 18)
                    branches.addLine(to: b)
                }
            }
        }
        var l = ctx
        l.blendMode = .plusLighter
        let glow = Color(hex: 0xB9C8FF)
        let a = min(1, f.intensity * 1.3)
        l.stroke(main, with: .color(glow.opacity(0.18 * a)), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
        l.stroke(main, with: .color(glow.opacity(0.45 * a)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
        l.stroke(branches, with: .color(glow.opacity(0.35 * a)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        l.stroke(main, with: .color(.white.opacity(a)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        l.stroke(branches, with: .color(.white.opacity(0.7 * a)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
    }

    private func drawFlash(_ ctx: inout GraphicsContext, _ f: Flash) {
        var l = ctx
        l.blendMode = .screen
        let rect = Path(CGRect(origin: .zero, size: size))
        l.fill(rect, with: .color(Color(hex: 0xC9D4FF, alpha: 0.22 * f.intensity)))
        l.fill(rect, with: .radialGradient(Gradient(colors: [Color(hex: 0xDDE4FF, alpha: 0.4 * f.intensity), .clear]),
                                           center: CGPoint(x: W * f.x, y: H * 0.15), startRadius: 0, endRadius: W * 0.6))
    }
}

/// Frost dendrites are static, so they're grown once per window size.
private enum FrostCache {
    private static var cache: (CGSize, Path)?

    static func path(for size: CGSize) -> Path {
        if let (s, p) = cache, s == size { return p }
        var path = Path()
        let corners: [(CGPoint, Double)] = [
            (.zero, .pi / 4), (CGPoint(x: size.width, y: 0), .pi * 3 / 4),
            (CGPoint(x: 0, y: size.height), -.pi / 4), (CGPoint(x: size.width, y: size.height), -.pi * 3 / 4),
        ]
        var seed = 0
        for (origin, aim) in corners {
            for k in 0..<7 {
                seed += 1
                let angle = aim + (Double(k) - 3) * 0.24 + (rnd(seed, 161) - 0.5) * 0.2
                grow(&path, from: origin, angle: angle, length: 40 + rnd(seed, 162) * 55, depth: 3, seed: seed * 17)
            }
        }
        cache = (size, path)
        return path
    }

    private static func grow(_ path: inout Path, from p: CGPoint, angle: Double, length: Double, depth: Int, seed: Int) {
        let end = CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
        path.move(to: p)
        path.addLine(to: end)
        guard depth > 0 else { return }
        let mid = CGPoint(x: (p.x + end.x) / 2, y: (p.y + end.y) / 2)
        grow(&path, from: mid, angle: angle + 1.05, length: length * 0.4, depth: depth - 1, seed: seed &* 3 &+ 1)
        grow(&path, from: mid, angle: angle - 1.05, length: length * 0.4, depth: depth - 1, seed: seed &* 3 &+ 2)
        grow(&path, from: end, angle: angle + (rnd(seed, 3) - 0.5) * 0.25, length: length * 0.55, depth: depth - 1, seed: seed &* 3 &+ 3)
    }
}
