import AppKit
import ImageIO
import UniformTypeIdentifiers

// A code-drawn app icon, reproducible without external image assets.
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
context.setFillColor(color(0.055, 0.09, 0.13)); context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(color(1, 0.75, 0.40)); context.fillEllipse(in: CGRect(x: 680, y: 675, width: 120, height: 120))
func mountain(_ points: [CGPoint], _ fill: CGColor) {
    context.beginPath(); context.addLines(between: points); context.closePath(); context.setFillColor(fill); context.fillPath()
}
mountain([CGPoint(x: 80,y: 220), CGPoint(x: 380,y: 710), CGPoint(x: 690,y: 220)], color(0.24,0.43,0.43))
mountain([CGPoint(x: 300,y: 220), CGPoint(x: 635,y: 820), CGPoint(x: 965,y: 220)], color(0.55,0.88,0.72))
mountain([CGPoint(x: 538,y: 648), CGPoint(x: 635,y: 820), CGPoint(x: 730,y: 648), CGPoint(x: 660,y: 690), CGPoint(x: 625,y: 664), CGPoint(x: 588,y: 700)], color(0.88,0.97,0.92))
context.setStrokeColor(color(1,0.75,0.40)); context.setLineWidth(25); context.setLineCap(.round)
context.move(to: CGPoint(x: 420,y: 150)); context.addCurve(to: CGPoint(x: 640,y: 570), control1: CGPoint(x: 900,y: 315), control2: CGPoint(x: 400,y: 400)); context.strokePath()
let image = context.makeImage()!
let url = URL(fileURLWithPath: "Trailhead/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write app icon") }
