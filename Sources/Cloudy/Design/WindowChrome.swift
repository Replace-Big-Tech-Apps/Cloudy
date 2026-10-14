import AppKit
import SwiftUI

/// Moves the traffic lights so they sit centered in our taller top bar, and keeps the
/// window to a single tab.
struct WindowChrome: NSViewRepresentable {
    static let barHeight: CGFloat = 56

    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) { view.relayout() }

    final class ChromeView: NSView {
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            window.tabbingMode = .disallowed
            window.isMovableByWindowBackground = true
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
            ]
            tokens = names.map {
                NotificationCenter.default.addObserver(forName: $0, object: window, queue: .main) { [weak self] _ in
                    self?.relayout()
                }
            }
            relayout()
        }

        /// Switching light/dark makes AppKit rebuild the titlebar at its default size,
        /// so move it back once AppKit's own pass has finished.
        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            relayout()
            for delay in [0, 0.15] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.relayout() }
            }
        }

        func relayout() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let titlebar = close.superview, let container = titlebar.superview else { return }
            let height = WindowChrome.barHeight
            container.frame = NSRect(x: 0, y: window.frame.height - height, width: window.frame.width, height: height)
            titlebar.frame = container.bounds
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            for (i, type) in buttons.enumerated() {
                guard let b = window.standardWindowButton(type) else { continue }
                b.setFrameOrigin(NSPoint(x: 20 + CGFloat(i) * 20, y: (height - b.frame.height) / 2))
            }
        }
    }
}

enum Appearance {
    static func apply(_ value: String) {
        NSApp.appearance = switch value {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    static func next(_ value: String) -> String {
        value == "system" ? "light" : value == "light" ? "dark" : "system"
    }

    static func symbol(_ value: String) -> String {
        switch value {
        case "light": "sun.max"
        case "dark": "moon"
        default: "circle.lefthalf.filled"
        }
    }
}
