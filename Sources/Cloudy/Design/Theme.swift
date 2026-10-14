import AppKit
import SwiftUI

// V3ERA widget language, shared with Times, Quill and Calcium: paper cards, black ink,
// hairlines, one yellow signal. Swap values here to re-theme the whole app.
extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32, alpha: Double = 1, darkAlpha: Double? = nil) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? (darkAlpha ?? alpha) : alpha
            )
        })
    }
}

enum V3 {
    static let desk = Color.dynamic(0xECECE8, 0x060607)
    static let paper = Color.dynamic(0xFEFEFE, 0x111113)
    static let paperSoft = Color.dynamic(0xF6F6F3, 0x19191C)
    static let ink = Color.dynamic(0x0A0A0B, 0xF3F3F0)
    static let mute = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.48, darkAlpha: 0.52)
    static let whisper = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.28, darkAlpha: 0.30)
    static let line = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.11, darkAlpha: 0.10)
    static let lineStrong = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.23, darkAlpha: 0.22)
    /// Text on an ink-filled control.
    static let inverse = Color.dynamic(0xFEFEFE, 0x0A0A0B)
    static let signal = Color.dynamic(0xF2C500, 0xF5CC1A)
    static let signalWash = Color.dynamic(0xFFFBE6, 0x2A2508)
    static let done = Color.dynamic(0xD94B3D, 0xEE6A5C)
    /// Always-dark face, like the V3ERA time widget's disc. Behind the sky while it loads.
    static let night = Color(red: 0.035, green: 0.035, blue: 0.04)

    static let radiusCard: CGFloat = 7
    static let radiusControl: CGFloat = 2

    enum Motion {
        static let fast = Animation.easeOut(duration: 0.12)
        static let base = Animation.easeOut(duration: 0.2)
        static let slow = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.4)
    }
}

enum V3Font {
    /// ui-monospace — tracked uppercase labels and small data.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Avenir Next Condensed — titles and the big numerals.
    static func condensed(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom("AvenirNextCondensed-\(weight.rawValue)", size: size)
    }
    enum Weight: String { case ultraLight = "UltraLight", regular = "Regular", medium = "Medium", demiBold = "DemiBold" }
}

extension View {
    /// V3ERA eyebrow: tiny tracked monospace caps.
    func eyebrow(_ color: Color = V3.whisper, size: CGFloat = 8) -> some View {
        font(V3Font.mono(size))
            .tracking(size * 0.26)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    func hairline(_ edges: Edge.Set, color: Color = V3.line) -> some View {
        overlay(alignment: .top) { if edges.contains(.top) { color.frame(height: 1) } }
            .overlay(alignment: .bottom) { if edges.contains(.bottom) { color.frame(height: 1) } }
            .overlay(alignment: .leading) { if edges.contains(.leading) { color.frame(width: 1) } }
            .overlay(alignment: .trailing) { if edges.contains(.trailing) { color.frame(width: 1) } }
    }

    /// Paper, strong hairline border, 7pt corners, soft drop shadow.
    func paperCard() -> some View {
        background(V3.paper)
            .clipShape(RoundedRectangle(cornerRadius: V3.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: V3.radiusCard).strokeBorder(V3.lineStrong))
            .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
    }
}

/// The V3ERA widget card: a header with an eyebrow, a condensed title and a monospace
/// status on the right, over a hairline.
struct WidgetCard<Accessory: View, Content: View>: View {
    let eyebrow: String
    let title: String
    var status: String = ""
    var statusColor: Color = V3.mute
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow).eyebrow(size: 7.5)
                    Text(title).font(V3Font.condensed(20)).foregroundStyle(V3.ink).lineLimit(1)
                }
                Spacer(minLength: 8)
                if !status.isEmpty { Text(status).eyebrow(statusColor, size: 7.5).lineLimit(1) }
                accessory
            }
            .padding(.horizontal, 17)
            .frame(minHeight: 60)
            .hairline(.bottom)
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .paperCard()
    }
}

extension WidgetCard where Accessory == EmptyView {
    init(eyebrow: String, title: String, status: String = "", statusColor: Color = V3.mute, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, status: status, statusColor: statusColor, accessory: { EmptyView() }, content: content)
    }
}

/// Square bordered button: paper fill, yellow on hover, ink when active.
struct SquareButton: View {
    let symbol: String
    var help: String = ""
    var size: CGFloat = 30
    var filled = false
    var spinning = false
    let action: () -> Void
    @State private var hover = false
    @State private var angle = 0.0

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .rotationEffect(.degrees(angle))
                .frame(width: size, height: size)
                .foregroundStyle(filled && !hover ? V3.inverse : V3.ink)
                .background(RoundedRectangle(cornerRadius: V3.radiusControl).fill(hover ? V3.signal : (filled ? V3.ink : V3.paper)))
                .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(hover || filled ? V3.ink : V3.lineStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
        .animation(V3.Motion.fast, value: hover)
        .onChange(of: spinning) { _, isSpinning in
            if isSpinning {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { angle = 360 }
            } else {
                withAnimation(.easeOut(duration: 0.3)) { angle = 0 }
            }
        }
    }
}

/// Wide monospace-caps button. `.ink` is the primary action.
struct BarButton: View {
    enum Kind { case plain, ink, signal }
    let title: String
    var kind: Kind = .plain
    var height: CGFloat = 38
    let action: () -> Void
    @State private var hover = false

    private var fill: Color {
        switch kind {
        case .plain: hover ? V3.ink : V3.paper
        case .ink: hover ? V3.signal : V3.ink
        case .signal: hover ? V3.ink : V3.signal
        }
    }

    private var text: Color {
        switch kind {
        case .plain: hover ? V3.inverse : V3.ink
        case .ink: hover ? .black : V3.inverse
        case .signal: hover ? V3.inverse : .black
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(V3Font.mono(8.5, .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(fill)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(V3.Motion.fast, value: hover)
    }
}

/// Small bordered chip, ink-filled when on (units, day / night, filters).
struct Chip: View {
    let title: String
    var on = false
    var width: CGFloat? = nil
    var height: CGFloat = 26
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(V3Font.mono(8.5, .bold))
                .tracking(1)
                .foregroundStyle(on ? V3.inverse : V3.ink)
                .padding(.horizontal, width == nil ? 10 : 0)
                .frame(width: width, height: height)
                .background(RoundedRectangle(cornerRadius: V3.radiusControl).fill(on ? V3.ink : (hover ? V3.signal : V3.paper)))
                .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(on || hover ? V3.ink : V3.lineStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Yellow tag with black caps ("HERE", "PREVIEW").
struct SignalTag: View {
    let text: String
    var size: CGFloat = 6.5

    var body: some View {
        Text(text).eyebrow(.black, size: size)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(V3.signal)
    }
}

/// A short line in the card's soft paper, used while data loads.
struct ShimmerBar: View {
    var body: some View {
        Rectangle()
            .fill(V3.paperSoft)
            .phaseAnimator([0.4, 1]) { v, phase in v.opacity(phase) } animation: { _ in .easeInOut(duration: 1) }
    }
}
