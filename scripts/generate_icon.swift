#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Minimalist Apple-style ClearDesk macOS App Icon generator (.icns + optional preview PNG)
let outputIcnsPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dist/AppIcon.icns"
let previewPngPath: String? = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

func renderIconPNG(size: Int) -> Data? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let cg = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }

    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // 1. Apple macOS squircle background
    let inset = s * 0.095
    let cardRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = cardRect.width * 0.225
    let bgPath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft ambient shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
    cg.addPath(bgPath)
    cg.setFillColor(CGColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0))
    cg.fillPath()
    cg.restoreGState()

    // Clean light-silver macOS background gradient
    cg.saveGState()
    cg.addPath(bgPath)
    cg.clip()
    let bgColors = [
        CGColor(red: 0.985, green: 0.99, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            grad,
            start: CGPoint(x: s * 0.5, y: cardRect.maxY),
            end: CGPoint(x: s * 0.5, y: cardRect.minY),
            options: []
        )
    }

    // 2. Minimalist back card (Desktop file gliding neatly into the Vault)
    let sheetW = cardRect.width * 0.56
    let sheetH = cardRect.height * 0.38
    let sheetRect = CGRect(
        x: cardRect.midX - sheetW * 0.5,
        y: cardRect.midY + cardRect.height * 0.02,
        width: sheetW,
        height: sheetH
    )
    let sheetPath = CGPath(roundedRect: sheetRect, cornerWidth: s * 0.045, cornerHeight: s * 0.045, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.025, color: CGColor(red: 0.08, green: 0.24, blue: 0.45, alpha: 0.14))
    cg.addPath(sheetPath)
    cg.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.97))
    cg.fillPath()
    cg.restoreGState()

    cg.addPath(sheetPath)
    cg.setStrokeColor(CGColor(red: 0.78, green: 0.84, blue: 0.92, alpha: 0.65))
    cg.setLineWidth(max(1.0, s * 0.004))
    cg.strokePath()

    // 3. Minimalist Apple-blue Vault tray in foreground
    let trayW = cardRect.width * 0.68
    let trayH = cardRect.height * 0.44
    let trayX = cardRect.midX - trayW * 0.5
    let trayY = cardRect.minY + cardRect.height * 0.17
    let trayRect = CGRect(x: trayX, y: trayY, width: trayW, height: trayH)
    let trayRadius = s * 0.075
    let trayPath = CGPath(roundedRect: trayRect, cornerWidth: trayRadius, cornerHeight: trayRadius, transform: nil)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.035, color: CGColor(red: 0.05, green: 0.32, blue: 0.68, alpha: 0.28))
    cg.addPath(trayPath)
    cg.setFillColor(CGColor(red: 0.22, green: 0.60, blue: 0.96, alpha: 1.0))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(trayPath)
    cg.clip()
    let trayColors = [
        CGColor(red: 0.36, green: 0.76, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.15, green: 0.50, blue: 0.93, alpha: 1.0)
    ] as CFArray
    if let trayGrad = CGGradient(colorsSpace: colorSpace, colors: trayColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            trayGrad,
            start: CGPoint(x: trayRect.midX, y: trayRect.maxY),
            end: CGPoint(x: trayRect.midX, y: trayRect.minY),
            options: []
        )
    }

    // Subtle top highlight bevel on tray
    cg.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    cg.setLineWidth(max(1.0, s * 0.008))
    cg.move(to: CGPoint(x: trayRect.minX + trayRadius * 0.5, y: trayRect.maxY - s * 0.005))
    cg.addLine(to: CGPoint(x: trayRect.maxX - trayRadius * 0.5, y: trayRect.maxY - s * 0.005))
    cg.strokePath()
    cg.restoreGState()

    // 4. Clean minimalist pill handle inside the Vault tray
    let handleW = trayW * 0.28
    let handleH = max(2.0, s * 0.032)
    let handleRect = CGRect(
        x: trayRect.midX - handleW * 0.5,
        y: trayRect.midY - handleH * 0.5,
        width: handleW,
        height: handleH
    )
    let handlePath = CGPath(roundedRect: handleRect, cornerWidth: handleH * 0.5, cornerHeight: handleH * 0.5, transform: nil)
    cg.addPath(handlePath)
    cg.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92))
    cg.fillPath()

    // Subtle outer glass rim
    cg.restoreGState()
    cg.addPath(bgPath)
    cg.setStrokeColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08))
    cg.setLineWidth(max(1.0, s * 0.005))
    cg.strokePath()

    guard let image = cg.makeImage() else { return nil }
    let mutableData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return mutableData as Data
}

// Official Apple ICNS PNG-chunk types covering 16px through 1024px Retina
let icnsEntries: [(fourCC: String, size: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
    ("ic11", 32),
    ("ic12", 64),
    ("ic13", 256),
    ("ic14", 512)
]

var body = Data()
var cachedPNGs: [Int: Data] = [:]

for entry in icnsEntries {
    let pngData: Data
    if let existing = cachedPNGs[entry.size] {
        pngData = existing
    } else {
        guard let rendered = renderIconPNG(size: entry.size) else {
            fputs("Failed to render \(entry.size)px icon\n", stderr)
            exit(1)
        }
        cachedPNGs[entry.size] = rendered
        pngData = rendered
    }

    var chunkLen = UInt32(8 + pngData.count).bigEndian
    body.append(entry.fourCC.data(using: .ascii)!)
    body.append(Data(bytes: &chunkLen, count: 4))
    body.append(pngData)
}

var icnsData = Data()
var totalLen = UInt32(8 + body.count).bigEndian
icnsData.append("icns".data(using: .ascii)!)
icnsData.append(Data(bytes: &totalLen, count: 4))
icnsData.append(body)

let outputURL = URL(fileURLWithPath: outputIcnsPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try icnsData.write(to: outputURL)

if let previewPngPath, let previewData = cachedPNGs[512] {
    let previewURL = URL(fileURLWithPath: previewPngPath)
    try FileManager.default.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try previewData.write(to: previewURL)
}

print("Generated minimalist macOS AppIcon.icns at \(outputURL.path)")
