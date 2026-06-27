import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("work/ChannelDeck.iconset", isDirectory: true)
let resources = root.appendingPathComponent("Resources", isDirectory: true)

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

let icons: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in icons {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let scale = size / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)

    drawIcon(in: context)

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(name)")
    }

    try data.write(to: iconset.appendingPathComponent(name))
}

func drawIcon(in context: CGContext) {
    let rect = CGRect(x: 80, y: 80, width: 864, height: 864)
    let rounded = CGPath(roundedRect: rect, cornerWidth: 210, cornerHeight: 210, transform: nil)

    let colors = [
        NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1).cgColor,
        NSColor(red: 0.08, green: 0.31, blue: 0.39, alpha: 1).cgColor,
        NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!

    context.saveGState()
    context.addPath(rounded)
    context.clip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 164, y: 94),
        end: CGPoint(x: 860, y: 930),
        options: []
    )
    context.restoreGState()

    drawPanel(in: context, rect: CGRect(x: 174, y: 252, width: 442, height: 314), alpha: 0.30)
    drawPanel(in: context, rect: CGRect(x: 246, y: 202, width: 442, height: 314), alpha: 0.46)

    let screen = CGPath(roundedRect: CGRect(x: 318, y: 266, width: 442, height: 314), cornerWidth: 72, cornerHeight: 72, transform: nil)
    let screenGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(red: 0.40, green: 0.91, blue: 0.98, alpha: 1).cgColor,
            NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!

    context.saveGState()
    context.addPath(screen)
    context.clip()
    context.drawLinearGradient(
        screenGradient,
        start: CGPoint(x: 274, y: 244),
        end: CGPoint(x: 734, y: 780),
        options: []
    )
    context.restoreGState()

    context.setFillColor(NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1).cgColor)
    let play = CGMutablePath()
    play.move(to: CGPoint(x: 486, y: 363))
    play.addLine(to: CGPoint(x: 486, y: 483))
    play.addCurve(to: CGPoint(x: 531, y: 507), control1: CGPoint(x: 486, y: 506), control2: CGPoint(x: 511, y: 520))
    play.addLine(to: CGPoint(x: 622, y: 447))
    play.addCurve(to: CGPoint(x: 622, y: 396), control1: CGPoint(x: 640, y: 435), control2: CGPoint(x: 640, y: 408))
    play.addLine(to: CGPoint(x: 531, y: 336))
    play.addCurve(to: CGPoint(x: 486, y: 363), control1: CGPoint(x: 511, y: 323), control2: CGPoint(x: 486, y: 337))
    play.closeSubpath()
    context.addPath(play)
    context.fillPath()

    drawLine(in: context, from: CGPoint(x: 310, y: 704), to: CGPoint(x: 714, y: 704), alpha: 0.94)
    drawLine(in: context, from: CGPoint(x: 382, y: 794), to: CGPoint(x: 642, y: 794), alpha: 0.62)
}

func drawPanel(in context: CGContext, rect: CGRect, alpha: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: 72, cornerHeight: 72, transform: nil)
    context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
    context.addPath(path)
    context.fillPath()
}

func drawLine(in context: CGContext, from: CGPoint, to: CGPoint, alpha: CGFloat) {
    context.setStrokeColor(NSColor.white.withAlphaComponent(alpha).cgColor)
    context.setLineWidth(54)
    context.setLineCap(.round)
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
}
