import SwiftUI
import AppKit
import CoreGraphics

public enum AppIcon {
    public static func upperTileCGPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 240, y: 249.271))
        path.addCurve(
            to: CGPoint(x: 248.292, y: 235.854),
            control1: CGPoint(x: 240, y: 243.589),
            control2: CGPoint(x: 243.21, y: 238.395)
        )
        path.addLine(to: CGPoint(x: 458.292, y: 130.854))
        path.addCurve(
            to: CGPoint(x: 480, y: 144.271),
            control1: CGPoint(x: 468.265, y: 125.867),
            control2: CGPoint(x: 480, y: 133.12)
        )
        path.addLine(to: CGPoint(x: 480, y: 230.729))
        path.addCurve(
            to: CGPoint(x: 471.708, y: 244.146),
            control1: CGPoint(x: 480, y: 236.411),
            control2: CGPoint(x: 476.79, y: 241.605)
        )
        path.addLine(to: CGPoint(x: 261.708, y: 349.146))
        path.addCurve(
            to: CGPoint(x: 240, y: 335.729),
            control1: CGPoint(x: 251.735, y: 354.133),
            control2: CGPoint(x: 240, y: 346.88)
        )
        path.addLine(to: CGPoint(x: 240, y: 249.271))
        path.closeSubpath()
        return path
    }

    public static func lowerTileCGPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 120, y: 369.271))
        path.addCurve(
            to: CGPoint(x: 128.292, y: 355.854),
            control1: CGPoint(x: 120, y: 363.589),
            control2: CGPoint(x: 123.21, y: 358.395)
        )
        path.addLine(to: CGPoint(x: 338.292, y: 250.854))
        path.addCurve(
            to: CGPoint(x: 360, y: 264.271),
            control1: CGPoint(x: 348.265, y: 245.867),
            control2: CGPoint(x: 360, y: 253.12)
        )
        path.addLine(to: CGPoint(x: 360, y: 350.729))
        path.addCurve(
            to: CGPoint(x: 351.708, y: 364.146),
            control1: CGPoint(x: 360, y: 356.411),
            control2: CGPoint(x: 356.79, y: 361.605)
        )
        path.addLine(to: CGPoint(x: 141.708, y: 469.146))
        path.addCurve(
            to: CGPoint(x: 120, y: 455.729),
            control1: CGPoint(x: 131.735, y: 474.133),
            control2: CGPoint(x: 120, y: 466.88)
        )
        path.addLine(to: CGPoint(x: 120, y: 369.271))
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
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

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

        let teal = CGColor(srgbRed: 0x2E / 255.0, green: 0xB8 / 255.0, blue: 0xB8 / 255.0, alpha: 1.0)
        let navy = CGColor(srgbRed: 0x1F / 255.0, green: 0x4D / 255.0, blue: 0x7A / 255.0, alpha: 1.0)
        let white = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        // Outer macOS icon drop shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -10.0 * scale),
            blur: 24.0 * scale,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28)
        )
        ctx.addPath(squirclePath)
        ctx.setFillColor(teal)
        ctx.fillPath()
        ctx.restoreGState()

        // Clip to squircle and draw SVG contents
        ctx.saveGState()
        ctx.addPath(squirclePath)
        ctx.clip()

        ctx.setFillColor(teal)
        ctx.fill(iconRect)

        // Map 600x600 SVG viewBox into 824x824 squircle
        ctx.translateBy(x: iconRect.minX, y: iconRect.minY)
        let svgScale: CGFloat = 824.0 / 600.0
        ctx.scaleBy(x: svgScale, y: svgScale)

        // Upper tile (fill="#1F4D7A")
        ctx.addPath(upperTileCGPath())
        ctx.setFillColor(navy)
        ctx.fillPath()

        // Lower tile (fill="white")
        ctx.addPath(lowerTileCGPath())
        ctx.setFillColor(white)
        ctx.fillPath()

        ctx.restoreGState()
        ctx.restoreGState()
    }
}
