import Cocoa

let w: CGFloat = 2880
let h: CGFloat = 1800
let image = NSImage(size: NSSize(width: w, height: h))
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
let rect = CGRect(x: 0, y: 0, width: w, height: h)

// Dark night-sky background: deep navy/purple to near-black
let bg = NSGradient(colors: [
    NSColor(srgbRed: 0.05, green: 0.02, blue: 0.12, alpha: 1),
    NSColor(srgbRed: 0.10, green: 0.03, blue: 0.20, alpha: 1),
    NSColor(srgbRed: 0.02, green: 0.01, blue: 0.06, alpha: 1)
])!
bg.draw(in: rect, angle: -90)

let horizonY = h * 0.42

// Big glowing outrun "sun" straddling the horizon
ctx.saveGState()
let sunCenter = CGPoint(x: w * 0.5, y: horizonY)
let sunRadius: CGFloat = 480
let sunGradient = NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.85, blue: 0.35, alpha: 1.0),
    NSColor(srgbRed: 1.0, green: 0.35, blue: 0.55, alpha: 1.0),
    NSColor(srgbRed: 0.85, green: 0.05, blue: 0.65, alpha: 0.0)
])!
sunGradient.draw(fromCenter: sunCenter, radius: 0, toCenter: sunCenter, radius: sunRadius, options: [])
// Horizontal scan-line bands cut across the lower part of the sun (classic synthwave sun)
NSColor(srgbRed: 0.02, green: 0.01, blue: 0.06, alpha: 1).setFill()
var bandY = horizonY - sunRadius * 0.55
var bandHeight: CGFloat = 10
var gap: CGFloat = 14
while bandY < horizonY + sunRadius {
    let bandRect = CGRect(x: sunCenter.x - sunRadius, y: bandY, width: sunRadius * 2, height: bandHeight)
    bandRect.intersection(CGRect(x: sunCenter.x - sunRadius, y: horizonY - sunRadius, width: sunRadius*2, height: sunRadius*2)).fill()
    bandY += bandHeight + gap
    bandHeight += 1.2
    gap = max(6, gap - 0.6)
}
ctx.restoreGState()

// Perspective neon grid floor below the horizon
ctx.saveGState()
let gridRect = CGRect(x: 0, y: 0, width: w, height: horizonY)
gridRect.clip()

let vanishX = w * 0.5
let vanishY = horizonY

// Vertical converging lines
let lineColor = NSColor(srgbRed: 0.15, green: 0.9, blue: 1.0, alpha: 0.55)
lineColor.setStroke()
let numVLines = 24
for i in 0...numVLines {
    let t = CGFloat(i) / CGFloat(numVLines)
    let xBottom = w * (t - 0.5) * 2.2 + vanishX
    let path = NSBezierPath()
    path.move(to: NSPoint(x: vanishX, y: vanishY))
    path.line(to: NSPoint(x: xBottom, y: -h * 0.3))
    path.lineWidth = 2
    path.stroke()
}

// Horizontal lines with perspective spacing (denser near horizon)
for i in 1...18 {
    let t = pow(CGFloat(i) / 18.0, 2.2)
    let y = vanishY - t * vanishY
    let alpha = 0.6 * (1.0 - t * 0.6)
    NSColor(srgbRed: 1.0, green: 0.15, blue: 0.75, alpha: alpha).setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 0, y: y))
    path.line(to: NSPoint(x: w, y: y))
    path.lineWidth = 2.2
    path.stroke()
}
ctx.restoreGState()

// City skyline silhouette along the horizon
ctx.saveGState()
var x: CGFloat = -50
var rng = SystemRandomNumberGenerator()
while x < w + 50 {
    let bw = CGFloat.random(in: 60...170, using: &rng)
    let bh = CGFloat.random(in: 120...520, using: &rng)
    let building = CGRect(x: x, y: horizonY, width: bw, height: bh)
    NSColor(srgbRed: 0.03, green: 0.02, blue: 0.08, alpha: 1).setFill()
    building.fill()

    // Neon-lit windows
    let cols = max(2, Int(bw / 22))
    let rows = max(2, Int(bh / 26))
    for c in 0..<cols {
        for r in 0..<rows {
            if Double.random(in: 0...1, using: &rng) < 0.35 {
                let winColors: [NSColor] = [
                    NSColor(srgbRed: 0.2, green: 0.95, blue: 1.0, alpha: 1),
                    NSColor(srgbRed: 1.0, green: 0.2, blue: 0.75, alpha: 1),
                    NSColor(srgbRed: 1.0, green: 0.85, blue: 0.35, alpha: 1)
                ]
                winColors.randomElement(using: &rng)!.setFill()
                let wx = x + 8 + CGFloat(c) * (bw - 16) / CGFloat(cols)
                let wy = horizonY + 10 + CGFloat(r) * (bh - 20) / CGFloat(rows)
                CGRect(x: wx, y: wy, width: 8, height: 12).fill()
            }
        }
    }
    x += bw + CGFloat.random(in: 4...18, using: &rng)
}
ctx.restoreGState()

// Reflection glow of the sun on the grid (soft magenta wash near horizon)
ctx.saveGState()
let reflect = NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.2, blue: 0.7, alpha: 0.25),
    NSColor(srgbRed: 1.0, green: 0.2, blue: 0.7, alpha: 0.0)
])!
reflect.draw(in: CGRect(x: 0, y: horizonY - 260, width: w, height: 260), angle: 90)
ctx.restoreGState()

// Subtle scanline overlay across the whole image for a CRT feel
ctx.saveGState()
NSColor.black.withAlphaComponent(0.08).setFill()
var sy: CGFloat = 0
while sy < h {
    CGRect(x: 0, y: sy, width: w, height: 2).fill()
    sy += 5
}
ctx.restoreGState()

// Vignette
ctx.saveGState()
let vignette = NSGradient(colors: [
    NSColor.black.withAlphaComponent(0.0),
    NSColor.black.withAlphaComponent(0.55)
])!
vignette.draw(in: rect, relativeCenterPosition: NSPoint(x: 0, y: 0.1))
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed")
}
try! png.write(to: URL(fileURLWithPath: "/tmp/cyberpunk_wallpaper.png"))
print("done")
