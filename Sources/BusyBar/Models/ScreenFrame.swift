import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A single captured frame from one of the bar's displays.
///
/// The endpoint advertises `image/bmp`, but the body is base64-encoded raw pixels rather than a
/// BMP file. The 72×16 front sends three bytes per pixel. The 160×80 back is a monochrome OLED
/// with 16 grey levels, so it packs two pixels into every byte — the even column in the low
/// nibble, the odd column in the high one.
public struct ScreenFrame: Sendable {
    public let screen: Screen
    public let width: Int
    public let height: Int
    public let pixels: Data

    public var bitsPerPixel: Int { screen.bitsPerPixel }

    /// Whether the frame is the size this display should produce.
    public var isWellFormed: Bool {
        pixels.count == screen.bytesPerRow * height
    }

    init(screen: Screen, pixels: Data) {
        self.screen = screen
        self.width = screen.pixelWidth
        self.height = screen.pixelHeight
        self.pixels = pixels
    }

    /// Red, green, and blue at a pixel, or `nil` when it falls outside the frame.
    ///
    /// A greyscale frame reports its single level in all three channels, scaled from the
    /// device's 16 steps to the full 0–255 range.
    public func pixel(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let rowStart = pixels.startIndex + y * screen.bytesPerRow

        switch bitsPerPixel {
        case 4:
            let index = rowStart + x / 2
            guard index < pixels.endIndex else { return nil }
            let byte = pixels[index]
            let level = x.isMultiple(of: 2) ? (byte & 0x0F) : (byte >> 4)
            let scaled = level * 17  // 0...15 spread across 0...255
            return (scaled, scaled, scaled)
        case 24:
            let index = rowStart + x * 3
            guard index + 2 < pixels.endIndex else { return nil }
            return (pixels[index], pixels[index + 1], pixels[index + 2])
        default:
            return nil
        }
    }

    #if canImport(CoreGraphics)
    /// The frame as an image, ready to draw. Expect it to look blocky — these are small panels.
    public func makeImage() -> CGImage? {
        guard bitsPerPixel > 0 else { return nil }

        var rgba = Data(capacity: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                guard let sample = pixel(x: x, y: y) else { break }
                rgba.append(sample.red)
                rgba.append(sample.green)
                rgba.append(sample.blue)
                rgba.append(255)
            }
        }
        guard rgba.count == width * height * 4, let provider = CGDataProvider(data: rgba as CFData)
        else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    #endif
}
