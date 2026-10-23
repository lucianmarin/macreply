import SwiftUI
import AppKit
import CoreGraphics

public enum AppIcon {
    public static func boltCGPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 215.426, y: 169.403))
        path.addCurve(
            to: CGPoint(x: 214.614, y: 159.047),
            control1: CGPoint(x: 212.646, y: 166.62),
            control2: CGPoint(x: 212.302, y: 162.229)
        )
        path.addLine(to: CGPoint(x: 260.076, y: 96.4716))
        path.addCurve(
            to: CGPoint(x: 249.429, y: 84.9451),
            control1: CGPoint(x: 265.219, y: 89.3922),
            control2: CGPoint(x: 256.893, y: 80.3787)
        )
        path.addLine(to: CGPoint(x: 127.925, y: 159.274))
        path.addCurve(
            to: CGPoint(x: 126.44, y: 171.753),
            control1: CGPoint(x: 123.511, y: 161.975),
            control2: CGPoint(x: 122.783, y: 168.092)
        )
        path.addLine(to: CGPoint(x: 169.24, y: 214.597))
        path.addCurve(
            to: CGPoint(x: 170.053, y: 224.953),
            control1: CGPoint(x: 172.02, y: 217.38),
            control2: CGPoint(x: 172.365, y: 221.771)
        )
        path.addLine(to: CGPoint(x: 124.591, y: 287.528))
        path.addCurve(
            to: CGPoint(x: 135.238, y: 299.055),
            control1: CGPoint(x: 119.448, y: 294.608),
            control2: CGPoint(x: 127.774, y: 303.621)
        )
        path.addLine(to: CGPoint(x: 256.741, y: 224.726))
        path.addCurve(
            to: CGPoint(x: 258.226, y: 212.247),
            control1: CGPoint(x: 261.155, y: 222.025),
            control2: CGPoint(x: 261.883, y: 215.908)
        )
        path.addLine(to: CGPoint(x: 215.426, y: 169.403))
        path.closeSubpath()
        return path
    }

    public static func renderPNGData(pixelSize: Int) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: pixelSize,
                  height: pixelSize,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        draw(in: ctx, pixelSize: pixelSize)

        guard let cgImage = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    public static func renderNSImage(pointSize: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        for scale in [1, 2] {
            let pixelSize = Int(pointSize) * scale
            if let data = renderPNGData(pixelSize: pixelSize),
               let rep = NSBitmapImageRep(data: data) {
                rep.size = NSSize(width: pointSize, height: pointSize)
                image.addRepresentation(rep)
            }
        }
        return image
    }

    public static func loadOrRenderImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return renderNSImage()
    }

    public static func writeIconset(to directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let specs: [(name: String, pixels: Int)] = [
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
        for spec in specs {
            guard let pngData = renderPNGData(pixelSize: spec.pixels) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try pngData.write(to: directoryURL.appendingPathComponent(spec.name))
        }
    }

    private static func draw(in ctx: CGContext, pixelSize: Int) {
        let size = CGFloat(pixelSize)
        let scale = size / 1024.0

        ctx.saveGState()
        // Flip vertically so (0, 0) is top-left matching SVG coordinates
        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: scale, y: -scale)

        let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
        let cornerRadius: CGFloat = 185.4
        let squirclePath = Path(
            roundedRect: iconRect,
            cornerRadius: cornerRadius,
            style: .continuous
        ).cgPath

        let orange = CGColor(srgbRed: 1.0, green: 0x40 / 255.0, blue: 0.0, alpha: 1.0)
        let black = CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let white = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        // Outer macOS icon drop shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -10.0 * scale),
            blur: 24.0 * scale,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28)
        )
        ctx.addPath(squirclePath)
        ctx.setFillColor(orange)
        ctx.fillPath()
        ctx.restoreGState()

        // Clip to squircle and draw SVG contents
        ctx.saveGState()
        ctx.addPath(squirclePath)
        ctx.clip()

        ctx.setFillColor(orange)
        ctx.fill(iconRect)

        // Map 384x384 SVG viewBox into 824x824 squircle
        ctx.translateBy(x: iconRect.minX, y: iconRect.minY)
        let svgScale: CGFloat = 824.0 / 384.0
        ctx.scaleBy(x: svgScale, y: svgScale)

        let bolt = boltCGPath()

        // Hard offset drop shadow (dx=12, dy=12 in 384x384 SVG coordinates)
        ctx.saveGState()
        ctx.translateBy(x: 12, y: 12)
        ctx.addPath(bolt)
        ctx.setFillColor(black)
        ctx.setStrokeColor(black)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()

        // White lightning bolt (fill="white" stroke="white" stroke-width="4")
        ctx.addPath(bolt)
        ctx.setFillColor(white)
        ctx.setStrokeColor(white)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)

        ctx.restoreGState()
        ctx.restoreGState()
    }
}
