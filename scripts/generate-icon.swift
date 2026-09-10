import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: generate-icon.swift output.png")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let canvas = NSRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: canvas.insetBy(dx: 48, dy: 48), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.72, alpha: 1)
])!
gradient.draw(in: background, angle: -65)

NSColor.white.withAlphaComponent(0.16).setFill()
NSBezierPath(ovalIn: NSRect(x: 210, y: 220, width: 604, height: 604)).fill()

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 442, y: 700))
arrow.line(to: NSPoint(x: 582, y: 700))
arrow.line(to: NSPoint(x: 582, y: 486))
arrow.line(to: NSPoint(x: 692, y: 486))
arrow.line(to: NSPoint(x: 512, y: 306))
arrow.line(to: NSPoint(x: 332, y: 486))
arrow.line(to: NSPoint(x: 442, y: 486))
arrow.close()
NSColor.white.setFill()
arrow.fill()

let tray = NSBezierPath(roundedRect: NSRect(x: 310, y: 228, width: 404, height: 54), xRadius: 27, yRadius: 27)
tray.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: outputURL)
