import Cocoa

let w: CGFloat = 2880
let h: CGFloat = 1800
let image = NSImage(size: NSSize(width: w, height: h))
image.lockFocus()

let rect = CGRect(x: 0, y: 0, width: w, height: h)

// Bold, high-contrast diagonal gradient: hot magenta -> electric blue -> acid yellow
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 1.00, green: 0.00, blue: 0.55, alpha: 1.0),
    NSColor(srgbRed: 0.55, green: 0.00, blue: 1.00, alpha: 1.0),
    NSColor(srgbRed: 0.00, green: 0.60, blue: 1.00, alpha: 1.0),
    NSColor(srgbRed: 1.00, green: 0.90, blue: 0.00, alpha: 1.0)
])!
gradient.draw(in: rect, angle: 35)

// Bold overlapping circles for extra punch/energy
let context = NSGraphicsContext.current!.cgContext
context.setBlendMode(.plusLighter)

func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: NSColor, _ alpha: CGFloat) {
    let path = NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    color.withAlphaComponent(alpha).setFill()
    path.fill()
}

circle(w * 0.15, h * 0.80, 500, .white, 0.18)
circle(w * 0.85, h * 0.20, 650, .white, 0.15)
circle(w * 0.55, h * 0.55, 420, NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), 0.10)
circle(w * 0.75, h * 0.75, 300, NSColor(srgbRed: 1.0, green: 0.2, blue: 0.6, alpha: 1), 0.25)
circle(w * 0.25, h * 0.25, 350, NSColor(srgbRed: 0.2, green: 0.8, blue: 1.0, alpha: 1), 0.25)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed")
}
try! png.write(to: URL(fileURLWithPath: "/tmp/shocking_wallpaper.png"))
print("done")
