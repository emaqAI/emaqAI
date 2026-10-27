import Cocoa

let w: CGFloat = 2880
let h: CGFloat = 1800
let image = NSImage(size: NSSize(width: w, height: h))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let rect = CGRect(x: 0, y: 0, width: w, height: h)
var rng = SystemRandomNumberGenerator()

// Moody dusk sky: deep indigo to near-black, faint teal near horizon
let sky = NSGradient(colors: [
    NSColor(srgbRed: 0.05, green: 0.06, blue: 0.10, alpha: 1),
    NSColor(srgbRed: 0.09, green: 0.12, blue: 0.18, alpha: 1),
    NSColor(srgbRed: 0.16, green: 0.20, blue: 0.24, alpha: 1)
])!
sky.draw(in: rect, angle: -90)

// Moon, partially veiled by thin cloud
ctx.saveGState()
let moonCenter = CGPoint(x: w * 0.72, y: h * 0.78)
let moonR: CGFloat = 190
let moonGlow = NSGradient(colors: [
    NSColor(srgbRed: 0.85, green: 0.88, blue: 0.80, alpha: 0.35),
    NSColor(srgbRed: 0.85, green: 0.88, blue: 0.80, alpha: 0.0)
])!
moonGlow.draw(fromCenter: moonCenter, radius: 0, toCenter: moonCenter, radius: moonR * 2.6, options: [])
NSColor(srgbRed: 0.90, green: 0.91, blue: 0.85, alpha: 0.95).setFill()
NSBezierPath(ovalIn: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR*2, height: moonR*2)).fill()
// craters
for _ in 0..<10 {
    let cr = CGFloat.random(in: 8...26, using: &rng)
    let angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
    let dist = CGFloat.random(in: 0...(moonR*0.7), using: &rng)
    let cx = moonCenter.x + cos(angle) * dist
    let cy = moonCenter.y + sin(angle) * dist
    NSColor(srgbRed: 0.75, green: 0.76, blue: 0.70, alpha: 0.5).setFill()
    NSBezierPath(ovalIn: CGRect(x: cx - cr/2, y: cy - cr/2, width: cr, height: cr)).fill()
}
ctx.restoreGState()

// Thin veiling clouds over the moon
ctx.saveGState()
for i in 0..<3 {
    let cy = moonCenter.y + CGFloat(i - 1) * 60
    let cloud = NSGradient(colors: [
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.0),
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.45),
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.0)
    ])!
    cloud.draw(in: CGRect(x: moonCenter.x - 500, y: cy - 40, width: 1000, height: 80), angle: 0)
}
ctx.restoreGState()

func silhouette(_ points: [(CGFloat, CGFloat)], color: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 0, y: 0))
    for p in points { path.line(to: NSPoint(x: p.0, y: p.1)) }
    path.line(to: NSPoint(x: w, y: 0))
    path.close()
    color.setFill()
    path.fill()
}

// Distant misty mountains (lighter, hazy)
var farPoints: [(CGFloat, CGFloat)] = [(0, h*0.42)]
var xx: CGFloat = 0
while xx < w {
    xx += CGFloat.random(in: 120...260, using: &rng)
    farPoints.append((xx, h * CGFloat.random(in: 0.40...0.52, using: &rng)))
}
silhouette(farPoints, color: NSColor(srgbRed: 0.20, green: 0.24, blue: 0.28, alpha: 1))

// Mid forest ridge (darker)
var midPoints: [(CGFloat, CGFloat)] = [(0, h*0.36)]
xx = 0
while xx < w {
    xx += CGFloat.random(in: 40...90, using: &rng)
    midPoints.append((xx, h * CGFloat.random(in: 0.30...0.40, using: &rng)))
}
silhouette(midPoints, color: NSColor(srgbRed: 0.09, green: 0.11, blue: 0.13, alpha: 1))

// Castle silhouette on a hill
ctx.saveGState()
let castleColor = NSColor(srgbRed: 0.05, green: 0.06, blue: 0.07, alpha: 1)
castleColor.setFill()
let baseX = w * 0.60
let baseY = h * 0.33
func tower(_ x: CGFloat, _ y: CGFloat, _ tw: CGFloat, _ th: CGFloat) {
    CGRect(x: x, y: y, width: tw, height: th).fill()
    // crenellations
    var cx = x
    while cx < x + tw {
        CGRect(x: cx, y: y + th, width: tw * 0.12, height: tw * 0.14).fill()
        cx += tw * 0.24
    }
    // conical roof for taller towers
    if th > 220 {
        let roof = NSBezierPath()
        roof.move(to: NSPoint(x: x - 6, y: y + th))
        roof.line(to: NSPoint(x: x + tw/2, y: y + th + tw*0.9))
        roof.line(to: NSPoint(x: x + tw + 6, y: y + th))
        roof.close()
        roof.fill()
    }
}
tower(baseX, baseY, 90, 260)
tower(baseX + 110, baseY, 140, 170)
tower(baseX + 270, baseY, 70, 320)
tower(baseX + 360, baseY, 100, 200)
// glowing window in the tallest tower
NSColor(srgbRed: 1.0, green: 0.65, blue: 0.25, alpha: 0.9).setFill()
CGRect(x: baseX + 300, y: baseY + 140, width: 14, height: 20).fill()
let windowGlow = NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.6, blue: 0.2, alpha: 0.35),
    NSColor(srgbRed: 1.0, green: 0.6, blue: 0.2, alpha: 0.0)
])!
windowGlow.draw(fromCenter: CGPoint(x: baseX + 307, y: baseY + 150), radius: 0, toCenter: CGPoint(x: baseX + 307, y: baseY + 150), radius: 90, options: [])
ctx.restoreGState()

// Ground fog band
ctx.saveGState()
let fog = NSGradient(colors: [
    NSColor(srgbRed: 0.35, green: 0.38, blue: 0.40, alpha: 0.0),
    NSColor(srgbRed: 0.45, green: 0.48, blue: 0.50, alpha: 0.35),
    NSColor(srgbRed: 0.45, green: 0.48, blue: 0.50, alpha: 0.0)
])!
fog.draw(in: CGRect(x: 0, y: h*0.20, width: w, height: h*0.20), angle: 90)
ctx.restoreGState()

// Foreground: bare twisted trees silhouette (very dark, close-up)
func tree(_ x: CGFloat, _ baseHeight: CGFloat, _ scale: CGFloat) {
    let path = NSBezierPath()
    path.lineWidth = 10 * scale
    path.lineCapStyle = .round
    NSColor(srgbRed: 0.02, green: 0.02, blue: 0.03, alpha: 1).setStroke()
    path.move(to: NSPoint(x: x, y: 0))
    path.curve(to: NSPoint(x: x + 20*scale, y: baseHeight),
               controlPoint1: NSPoint(x: x - 10*scale, y: baseHeight*0.3),
               controlPoint2: NSPoint(x: x + 30*scale, y: baseHeight*0.7))
    path.stroke()
    // branches
    for i in 0..<5 {
        let t = CGFloat(i) / 5.0
        let by = baseHeight * (0.35 + t * 0.6)
        let bx = x + 20*scale * t
        let branch = NSBezierPath()
        branch.lineWidth = max(2, 7 * scale * (1 - t))
        branch.move(to: NSPoint(x: bx, y: by))
        let dir: CGFloat = i % 2 == 0 ? 1 : -1
        branch.curve(to: NSPoint(x: bx + dir * 90 * scale * (1-t+0.3), y: by + 70*scale*(1-t+0.2)),
                     controlPoint1: NSPoint(x: bx + dir * 30*scale, y: by + 20*scale),
                     controlPoint2: NSPoint(x: bx + dir * 60*scale, y: by + 50*scale))
        branch.stroke()
    }
}
tree(w * 0.06, 520, 2.0)
tree(w * 0.15, 380, 1.4)
tree(w * 0.92, 480, 1.8)
tree(w * 0.82, 340, 1.2)

// Subtle vignette
ctx.saveGState()
let vignette = NSGradient(colors: [
    NSColor.black.withAlphaComponent(0.0),
    NSColor.black.withAlphaComponent(0.5)
])!
vignette.draw(in: rect, relativeCenterPosition: NSPoint(x: 0, y: 0.15))
ctx.restoreGState()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed")
}
try! png.write(to: URL(fileURLWithPath: "/tmp/witcher_wallpaper.png"))
print("done")
