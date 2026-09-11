import Cocoa

// Click-through, borderless overlay that pulses a green glow around the
// edge of every connected screen. Meant to be started/stopped as an
// external "Claude is active on this machine" indicator, since the host
// app's own screen-control indicator isn't customizable.

final class GlowWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class GlowView: NSView {
    private let borderLayer = CAShapeLayer()
    private let lineWidth: CGFloat = 10

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBorder()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func setupBorder() {
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.systemGreen.cgColor
        borderLayer.lineWidth = lineWidth
        borderLayer.shadowColor = NSColor.systemGreen.cgColor
        borderLayer.shadowOpacity = 1.0
        borderLayer.shadowRadius = 20
        borderLayer.shadowOffset = .zero
        layer?.addSublayer(borderLayer)
        updatePath()

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.35
        pulse.toValue = 1.0
        pulse.duration = 1.1
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        borderLayer.add(pulse, forKey: "pulse")
    }

    private func updatePath() {
        let inset = lineWidth / 2
        borderLayer.frame = bounds
        borderLayer.path = CGPath(rect: bounds.insetBy(dx: inset, dy: inset), transform: nil)
    }

    override func layout() {
        super.layout()
        updatePath()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        for screen in NSScreen.screens {
            let window = GlowWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

            let view = GlowView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            window.contentView = view

            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
