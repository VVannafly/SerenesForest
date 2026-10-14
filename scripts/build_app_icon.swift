import AppKit

// Builds the app icon from the same Shield of Flames art used on Discover.
let side = 1024
let destination = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIcon.xcassets/AppIcon.appiconset/AppIcon.png"
let shieldPath = "Resources/AppIcon.xcassets/ShieldOfFlames.imageset/ShieldOfFlames.png"
guard let shieldData = try? Data(contentsOf: URL(fileURLWithPath: shieldPath)),
      let shield = NSImage(data: shieldData),
      let shieldBitmap = NSBitmapImageRep(data: shieldData),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                   bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not load Shield of Flames or create icon bitmap")
}

// The source PNG includes uneven transparent margins and a soft shadow. Center
// the opaque shield itself, rather than the PNG canvas, inside the background.
var visibleMinX = shieldBitmap.pixelsWide
var visibleMaxX = -1
for y in 0..<shieldBitmap.pixelsHigh {
    for x in 0..<shieldBitmap.pixelsWide where (shieldBitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.9 {
        visibleMinX = min(visibleMinX, x)
        visibleMaxX = max(visibleMaxX, x)
    }
}
guard visibleMaxX >= visibleMinX else { fatalError("Shield of Flames is transparent") }
let shieldWidth: CGFloat = 696
let visibleCenter = CGFloat(visibleMinX + visibleMaxX + 1) / 2
let shieldX = (CGFloat(side) - shieldWidth) / 2
    + (CGFloat(shieldBitmap.pixelsWide) / 2 - visibleCenter) * shieldWidth / CGFloat(shieldBitmap.pixelsWide)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true

let bounds = NSRect(x: 0, y: 0, width: side, height: side)
NSGradient(starting: color(16, 25, 55), ending: color(66, 43, 96))!
    .draw(in: bounds, angle: -35)

let halo = NSBezierPath(ovalIn: NSRect(x: 100, y: 95, width: 824, height: 824))
color(111, 91, 166, 0.23).setFill()
halo.fill()
halo.lineWidth = 10
color(239, 192, 91, 0.19).setStroke()
halo.stroke()

let innerRing = NSBezierPath(ovalIn: NSRect(x: 142, y: 137, width: 740, height: 740))
innerRing.lineWidth = 3
color(255, 225, 156, 0.13).setStroke()
innerRing.stroke()

let shadow = NSShadow()
shadow.shadowColor = color(0, 0, 0, 0.45)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.set()
shield.draw(in: NSRect(x: shieldX, y: 100, width: shieldWidth, height: 802),
            from: .zero, operation: .sourceOver, fraction: 1)

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode app icon")
}
try data.write(to: URL(fileURLWithPath: destination))

let sourceImage = NSImage(data: data)!
let folder = URL(fileURLWithPath: destination).deletingLastPathComponent()
for size in [16, 32, 64, 128, 256, 512] {
    guard let thumbnail = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                           bitsPerPixel: 0),
          let thumbnailContext = NSGraphicsContext(bitmapImageRep: thumbnail) else {
        fatalError("Could not create \(size)px icon")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = thumbnailContext
    thumbnailContext.imageInterpolation = .high
    sourceImage.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    thumbnailContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let thumbnailData = thumbnail.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(size)px icon")
    }
    try thumbnailData.write(to: folder.appendingPathComponent("Icon-\(size).png"))
}
