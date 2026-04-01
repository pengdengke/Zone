import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: swift scripts/generate_app_icon.swift <AppIcon.appiconset>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconNames: [(String, CGFloat)] = [
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

func makeImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor(calibratedRed: 0.08, green: 0.44, blue: 0.73, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    ).fill()

    NSColor.white.setStroke()

    let outer = NSBezierPath()
    outer.lineWidth = size * 0.08
    outer.appendOval(in: NSRect(x: size * 0.2, y: size * 0.2, width: size * 0.6, height: size * 0.6))
    outer.stroke()

    let inner = NSBezierPath()
    inner.lineWidth = size * 0.08
    inner.appendOval(in: NSRect(x: size * 0.35, y: size * 0.35, width: size * 0.3, height: size * 0.3))
    inner.stroke()

    image.unlockFocus()
    return image
}

for (name, size) in iconNames {
    let image = makeImage(size: size)
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fatalError("failed to render \(name)")
    }

    try png.write(to: outputURL.appendingPathComponent(name))
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contents.data(using: .utf8)!.write(to: outputURL.appendingPathComponent("Contents.json"))
