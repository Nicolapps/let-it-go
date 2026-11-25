// Renders an App Store product page header: the app's aurora background and
// snow, with the icon and the name inside Apple's art safe area.
//
//   just app-store-header <name> [--content icon-name|name|tagline|none]
//                                [--lockup <scale>] [--drop <pixels>] [--guides]
//
// which writes screenshots/headers/<name>-3840x1646.png. `--content` picks what
// goes on the background, `--lockup` shrinks or grows it, `--drop` moves it down
// from the middle of the safe area, and `--guides` outlines that area.
//
// Sizes are Apple's, from "Creative assets specifications" in App Store Connect
// Help: a 3840 x 1646 canvas whose art safe area is 1646 x 661 at (1097, 493).
// An iPhone shows the middle 84% of the width and all of the height, with its
// back and share buttons over the top corners, clear of the safe area. Other
// devices may show less, so what matters stays inside it.

import AppKit
import SwiftUI

private let canvas = CGSize(width: 3840, height: 1646)
private let safeArea = CGRect(x: 1097, y: 493, width: 1646, height: 661)

private extension Color {
    static let indigoGlow = Color(hex: 0x6A6AB8)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The same mesh as `AuroraBackground` in ContentView.swift.
private struct AuroraBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.38], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(hex: 0x0E0F33), Color(hex: 0x1A1A55), Color(hex: 0x332F7D),
                Color(hex: 0x262668), .indigoGlow, Color(hex: 0x3B2D84),
                Color(hex: 0x6F80C2), Color(hex: 0x6A3F98), Color(hex: 0xC070B8),
            ]
        )
    }
}

/// The same every run, so a re-render only changes what was edited.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Still flakes in the app's sizes and opacities, scaled up with the icon, and
/// kept off the icon and the name.
private struct Snow: View {
    var clear: CGRect

    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(state: 41)
            var drawn = 0
            while drawn < 170 {
                let point = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng))
                let diameter = CGFloat.random(in: 1.5...4, using: &rng) * Banner.scale
                let opacity = Double.random(in: 0.15...0.55, using: &rng)
                guard !clear.contains(point) else { continue }
                drawn += 1
                let rect = CGRect(x: point.x, y: point.y, width: diameter, height: diameter)
                context.fill(Circle().path(in: rect), with: .color(.white.opacity(opacity)))
            }
        }
    }
}

private enum Content: String {
    case iconAndName = "icon-name"
    case name
    case tagline
    case none
}

private struct Banner: View {
    var icon: NSImage
    var content: Content
    var lockupScale: CGFloat
    var drop: CGFloat
    var showsGuides: Bool

    /// Banner pixels per point of the app's layout, where the icon is 112 pt.
    static let scale: CGFloat = 380 / 112

    var body: some View {
        ZStack(alignment: .topLeading) {
            AuroraBackground()
            Snow(clear: content == .none ? .null : safeArea.insetBy(dx: -40, dy: 60).offsetBy(dx: 0, dy: drop))

            let scale = Self.scale * lockupScale
            HStack(spacing: 28 * scale) {
                if content == .iconAndName {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 112 * scale, height: 112 * scale)
                        .shadow(color: .indigoGlow.opacity(0.6), radius: 40 * scale, y: 12 * scale)
                }

                Group {
                    switch content {
                    case .iconAndName, .name:
                        Text("Let It Go")
                            .font(.system(size: 70 * scale, weight: .bold))
                    case .tagline:
                        // The website's tagline, on two lines to stay between the buttons.
                        Text("Makes go/ links\nwork in Safari.")
                            .font(.system(size: 34 * scale, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4 * scale)
                    case .none:
                        EmptyView()
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: Color(hex: 0x0E0F33).opacity(0.55), radius: 10 * scale, y: 3 * scale)
                .fixedSize()
            }
            .frame(width: safeArea.width, height: safeArea.height)
            .offset(x: safeArea.minX, y: safeArea.minY + drop)

            if showsGuides {
                Rectangle()
                    .strokeBorder(.yellow, style: StrokeStyle(lineWidth: 6, dash: [28, 18]))
                    .frame(width: safeArea.width, height: safeArea.height)
                    .offset(x: safeArea.minX, y: safeArea.minY)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

@main
private enum Main {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3, let icon = NSImage(contentsOfFile: arguments[1]) else {
            FileHandle.standardError.write(Data("usage: app-store-header <icon.png> <output.png> [--content icon-name|name|tagline|none] [--lockup <scale>] [--drop <pixels>] [--guides]\n".utf8))
            exit(2)
        }
        func value(of option: String) -> Double? {
            arguments.firstIndex(of: option).flatMap { arguments.indices.contains($0 + 1) ? Double(arguments[$0 + 1]) : nil }
        }

        let contentName = arguments.firstIndex(of: "--content").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        guard let content = Content(rawValue: contentName ?? Content.iconAndName.rawValue) else {
            FileHandle.standardError.write(Data("--content is one of icon-name, name, tagline, none\n".utf8))
            exit(2)
        }

        let banner = Banner(
            icon: icon,
            content: content,
            lockupScale: value(of: "--lockup") ?? 1,
            drop: value(of: "--drop") ?? 0,
            showsGuides: arguments.contains("--guides")
        )
        let renderer = ImageRenderer(content: banner)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            FileHandle.standardError.write(Data("Couldn't render the banner\n".utf8))
            exit(1)
        }

        // App Store Connect refuses images with an alpha channel.
        let width = image.width, height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { exit(1) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let opaque = context.makeImage()!

        let url = URL(fileURLWithPath: arguments[2])
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, opaque, nil)
        guard CGImageDestinationFinalize(destination) else { exit(1) }
        print("\(url.lastPathComponent): \(width) x \(height)")
    }
}
