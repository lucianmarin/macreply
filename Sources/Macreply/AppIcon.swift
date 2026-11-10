import SwiftUI
import AppKit
import CoreGraphics

public enum AppIcon {
    public enum AppearanceMode: String, CaseIterable, Sendable {
        case light
        case dark
    }

    public static let lightSVG = """
    <svg width="600" height="600" viewBox="0 0 600 600" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="600" height="600" fill="#2EB8B8"/>
    <path d="M240 249.271C240 243.589 243.21 238.395 248.292 235.854L458.292 130.854C468.265 125.867 480 133.12 480 144.271V230.729C480 236.411 476.79 241.605 471.708 244.146L261.708 349.146C251.735 354.133 240 346.88 240 335.729V249.271Z" fill="#1F4D7A"/>
    <path d="M120 369.271C120 363.589 123.21 358.395 128.292 355.854L338.292 250.854C348.265 245.867 360 253.12 360 264.271V350.729C360 356.411 356.79 361.605 351.708 364.146L141.708 469.146C131.735 474.133 120 466.88 120 455.729V369.271Z" fill="white"/>
    </svg>
    """

    public static let darkSVG = """
    <svg width="600" height="600" viewBox="0 0 600 600" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="600" height="600" fill="#1F4D7A"/>
    <path d="M240 249.271C240 243.589 243.21 238.395 248.292 235.854L458.292 130.854C468.265 125.867 480 133.12 480 144.271V230.729C480 236.411 476.79 241.605 471.708 244.146L261.708 349.146C251.735 354.133 240 346.88 240 335.729V249.271Z" fill="white"/>
    <path d="M120 369.271C120 363.589 123.21 358.395 128.292 355.854L338.292 250.854C348.265 245.867 360 253.12 360 264.271V350.729C360 356.411 356.79 361.605 351.708 364.146L141.708 469.146C131.735 474.133 120 466.88 120 455.729V369.271Z" fill="#2EB8B8"/>
    </svg>
    """

    @MainActor
    private static var appearanceObservation: NSKeyValueObservation?
    @MainActor
    private static var themeNotificationObserver: NSObjectProtocol?

    public static func mode(for appearance: NSAppearance?) -> AppearanceMode {
        guard let appearance else { return .light }
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }

    @MainActor
    public static func currentMode() -> AppearanceMode {
        mode(for: NSApp?.effectiveAppearance)
    }

    @MainActor
    public static func updateApplicationIcon(for appearance: NSAppearance? = nil) {
        let resolvedAppearance = appearance ?? NSApp?.effectiveAppearance
        NSApplication.shared.applicationIconImage = loadOrRenderImage(for: resolvedAppearance)
    }

    @MainActor
    public static func installAppearanceObserver() {
        updateApplicationIcon()
        if appearanceObservation == nil {
            appearanceObservation = NSApplication.shared.observe(
                \.effectiveAppearance,
                options: [.new]
            ) { _, _ in
                Task { @MainActor in
                    updateApplicationIcon()
                }
            }
        }
        if themeNotificationObserver == nil {
            themeNotificationObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    updateApplicationIcon()
                }
            }
        }
    }

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

    public static func renderPNGData(pixelSize: Int, mode: AppearanceMode = .light) -> Data? {
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

        draw(in: ctx, pixelSize: pixelSize, mode: mode)

        guard let cgImage = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    public static func renderNSImage(pointSize: CGFloat = 512, mode: AppearanceMode = .light) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        for scale in [1, 2] {
            let pixelSize = Int(pointSize) * scale
            if let data = renderPNGData(pixelSize: pixelSize, mode: mode),
               let rep = NSBitmapImageRep(data: data) {
                rep.size = NSSize(width: pointSize, height: pointSize)
                image.addRepresentation(rep)
            }
        }
        return image
    }

    public static func loadOrRenderImage(for appearance: NSAppearance? = nil) -> NSImage {
        renderNSImage(mode: mode(for: appearance))
    }

    public static func writeIconset(to directoryURL: URL, mode: AppearanceMode = .light) throws {
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
            guard let pngData = renderPNGData(pixelSize: spec.pixels, mode: mode) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try pngData.write(to: directoryURL.appendingPathComponent(spec.name))
        }
    }

    /// Writes a macOS Icon Composer `.icon` bundle with `light.svg` (light/default) and `dark.svg` (dark)
    /// for compilation with `xcrun actool` into a multi-appearance `Assets.car` and `AppIcon.icns`.
    public static func writeIconComposerBundle(to directoryURL: URL) throws {
        let assetsURL = directoryURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        try Data(lightSVG.utf8).write(to: assetsURL.appendingPathComponent("light.svg"))
        try Data(darkSVG.utf8).write(to: assetsURL.appendingPathComponent("dark.svg"))

        let iconJSON = """
        {
          "fill-specializations" : [
            {
              "value" : {
                "solid" : "srgb:0.18039,0.72157,0.72157,1.00000"
              }
            },
            {
              "appearance" : "dark",
              "value" : {
                "solid" : "srgb:0.12157,0.30196,0.47843,1.00000"
              }
            }
          ],
          "groups" : [
            {
              "layers" : [
                {
                  "glass" : false,
                  "image-name-specializations" : [
                    {
                      "value" : "light.svg"
                    },
                    {
                      "appearance" : "dark",
                      "value" : "dark.svg"
                    }
                  ],
                  "name" : "icon",
                  "position" : {
                    "scale" : 1.7066666666666668,
                    "translation-in-points" : [
                      0,
                      0
                    ]
                  }
                }
              ],
              "lighting" : "individual",
              "shadow" : {
                "kind" : "none",
                "opacity" : 0.0
              },
              "specular" : false,
              "translucency" : {
                "enabled" : false,
                "value" : 0.0
              }
            }
          ],
          "supported-platforms" : {
            "squares" : [
              "macOS"
            ]
          }
        }
        """
        try Data(iconJSON.utf8).write(to: directoryURL.appendingPathComponent("icon.json"))
    }

    private static func draw(in ctx: CGContext, pixelSize: Int, mode: AppearanceMode = .light) {
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

        let backgroundColor: CGColor
        let upperTileColor: CGColor
        let lowerTileColor: CGColor

        switch mode {
        case .light:
            // Matches light.svg: rect=#2EB8B8, upper=#1F4D7A, lower=white
            backgroundColor = teal
            upperTileColor = navy
            lowerTileColor = white
        case .dark:
            // Matches dark.svg: rect=#1F4D7A, upper=white, lower=#2EB8B8
            backgroundColor = navy
            upperTileColor = white
            lowerTileColor = teal
        }

        // Composite squircle and SVG artwork inside a transparency layer so the macOS drop shadow is applied cleanly once
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -10.0 * scale),
            blur: 24.0 * scale,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28)
        )
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)

        ctx.addPath(squirclePath)
        ctx.clip()

        ctx.setFillColor(backgroundColor)
        ctx.fill(iconRect)

        // Map 600x600 SVG viewBox into 824x824 squircle
        ctx.translateBy(x: iconRect.minX, y: iconRect.minY)
        let svgScale: CGFloat = 824.0 / 600.0
        ctx.scaleBy(x: svgScale, y: svgScale)

        // Upper tile
        ctx.addPath(upperTileCGPath())
        ctx.setFillColor(upperTileColor)
        ctx.fillPath()

        // Lower tile
        ctx.addPath(lowerTileCGPath())
        ctx.setFillColor(lowerTileColor)
        ctx.fillPath()

        ctx.endTransparencyLayer()
        ctx.restoreGState()
        ctx.restoreGState()
    }
}
