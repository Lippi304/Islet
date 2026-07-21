#!/usr/bin/env swift
// Draws the DMG installer window background: a dark canvas (matches Islet's
// own notch-black aesthetic) with a light arrow pointing from the app icon
// position to the Applications-folder icon position. Run via `swift
// scripts/generate-dmg-background.swift <output.png>` — no extra tools/deps,
// just AppKit (already available via the Xcode toolchain).

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "background.png"

// Must match DMG_WINDOW_WIDTH/HEIGHT and the two icon X positions in
// scripts/release.sh's Finder AppleScript step — all four numbers describe
// the same window, so keep them in sync if any of them ever changes.
let width = 540
let height = 380
let iconY = 190          // vertical center both icons sit at (AppleScript uses the same value)
let appIconX = 140       // Islet.app icon center
let applicationsX = 400  // Applications symlink icon center

// Render into an explicit 1x-pixel-exact bitmap rather than NSImage.lockFocus()
// — lockFocus() draws at the MAIN SCREEN's backing scale factor (2x on any
// Retina display), which would silently double the actual pixel dimensions
// and make Finder position this background at 2x the size release.sh's
// AppleScript step expects (both must agree on the same 540x380 coordinate
// space — see the comment above).
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write("Failed to allocate bitmap\n".data(using: .utf8)!)
    exit(1)
}
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let size = NSSize(width: width, height: height)

NSColor(calibratedWhite: 0.11, alpha: 1.0).setFill()
NSRect(origin: .zero, size: size).fill()

let arrowColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
let arrowY = CGFloat(iconY)
let arrowStartX = CGFloat(appIconX) + 55
let arrowEndX = CGFloat(applicationsX) - 55

let shaft = NSBezierPath()
shaft.lineWidth = 3
shaft.move(to: NSPoint(x: arrowStartX, y: arrowY))
shaft.line(to: NSPoint(x: arrowEndX - 14, y: arrowY))
arrowColor.setStroke()
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEndX - 14, y: arrowY + 10))
head.line(to: NSPoint(x: arrowEndX, y: arrowY))
head.line(to: NSPoint(x: arrowEndX - 14, y: arrowY - 10))
head.close()
arrowColor.setFill()
head.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to render background PNG\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("-> Wrote \(outputPath) (\(width)x\(height))")
} catch {
    FileHandle.standardError.write("Failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
