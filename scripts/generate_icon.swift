// Draws the Cloudy app icon — a halftone dot-matrix cloud on a white squircle,
// with an amber dot as the sun, like the other Replace-Big-Tech-Apps icons. Writes a 1024px PNG.
// Usage: swift scripts/generate_icon.swift out.png
import AppKit
import CoreGraphics

let size = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Squircle body (macOS icon grid: 824px artwork inside 1024).
let inset: CGFloat = 100
let body = CGRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 34, color: color(0x000000, 0.28))
ctx.addPath(squircle)
ctx.setFillColor(color(0xFAFAF7))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let paper = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF), color(0xF1F1EC)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(paper, start: CGPoint(x: 512, y: inset), end: CGPoint(x: 512, y: 1024 - inset), options: [])

// Cloud silhouette: three puffs on a flat, rounded base.
struct Circle { let x, y, r: CGFloat }
let puffs = [Circle(x: 352, y: 612, r: 92), Circle(x: 498, y: 528, r: 138), Circle(x: 662, y: 588, r: 112)]
let base = CGRect(x: 262, y: 640, width: 512, height: 100)
let baseRadius: CGFloat = 50

/// How far (px) a point sits inside the cloud; negative outside.
func depth(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
    var d = -CGFloat.infinity
    for p in puffs { d = max(d, p.r - hypot(x - p.x, y - p.y)) }
    // rounded-rect signed distance
    let cx = base.midX, cy = base.midY
    let qx = abs(x - cx) - (base.width / 2 - baseRadius)
    let qy = abs(y - cy) - (base.height / 2 - baseRadius)
    let outside = hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0)
    return max(d, baseRadius - outside)
}

/// True distance to the silhouette edge (capped), found by marching outward
/// in 32 directions — avoids seams where the shapes of the union overlap.
func edgeDistance(_ x: CGFloat, _ y: CGFloat, limit: CGFloat) -> CGFloat {
    var best = limit
    for k in 0..<32 {
        let a = CGFloat(k) / 32 * 2 * .pi
        var r: CGFloat = 1
        while r < best {
            if depth(x + cos(a) * r, y + sin(a) * r) <= 0 { best = r; break }
            r += 1
        }
    }
    return best
}

// Halftone: a square dot grid; dots grow toward the cloud's shaded underside
// and shrink to nothing at the edges, like a printed screen.
let pitch: CGFloat = 14
let maxR = pitch * 0.47
let top: CGFloat = 385, bottom: CGFloat = 742
ctx.setFillColor(color(0x161719))
var y = top
while y <= bottom + pitch {
    var x: CGFloat = 232
    while x <= 800 {
        if depth(x, y) > 0 {
            let edge = min(1, edgeDistance(x, y, limit: 26) / 26)
            let shade = 0.32 + 0.68 * pow(min(1, max(0, (y - top) / (bottom - top))), 1.25)
            let r = maxR * max(0.18, sqrt(edge * shade))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        x += pitch
    }
    y += pitch
}

// Amber sun.
let sun = CGPoint(x: 790, y: 234)
ctx.setFillColor(color(0xD4860A))
ctx.fillEllipse(in: CGRect(x: sun.x - 40, y: sun.y - 40, width: 80, height: 80))
ctx.restoreGState()

// Hairline edge.
ctx.addPath(squircle)
ctx.setStrokeColor(color(0x000000, 0.06))
ctx.setLineWidth(2)
ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
