// Rewrites PNGs in place without their alpha channel, which App Store Connect
// refuses even when every pixel is opaque. The simulator's screenshots have one.
//
//   swift scripts/opaque-png.swift <file.png> ...

import CoreGraphics
import Foundation
import ImageIO

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(
              data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          )
    else {
        FileHandle.standardError.write(Data("Couldn't read \(path)\n".utf8))
        exit(1)
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let opaque = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { exit(1) }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("Couldn't write \(path)\n".utf8))
        exit(1)
    }
}
