import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A single captured frame from one of the bar's displays.
///
/// The endpoint advertises `image/bmp`, but the body is base64-encoded raw pixels rather than a
/// BMP file: the 72×16 front sends 3 bytes per pixel, the 80×80 back a single greyscale byte.
public struct ScreenFrame: Sendable {
    public let screen: Screen
    public let width: Int
    public let height: Int
    public let pixels: Data

    /// Taken from the frame itself, so an unexpected size is visible rather than assumed.
    public var bytesPerPixel: Int {
        let count = width * height
        return count > 0 ? pixels.count / count : 0
    }

    init(screen: Screen, pixels: Data) {
        self.screen = screen
        self.width = screen.pixelWidth
        self.height = screen.pixelHeight
        self.pixels = pixels
    }

    /// Red, green, and blue at a pixel, or `nil` when it falls outside the frame.
    ///
    /// A greyscale frame reports its single value in all three channels.
    public func pixel(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        let stride = bytesPerPixel
        guard stride >= 1, (0..<width).contains(x), (0..<height).contains(y) else { return nil }

        let offset = (y * width + x) * stride
        guard offset + stride <= pixels.count else { return nil }

        if stride == 1 {
            let level = pixels[pixels.startIndex + offset]
            return (level, level, level)
        }
        let base = pixels.startIndex + offset
        return (pixels[base], pixels[base + 1], pixels[base + 2])
    }

    #if canImport(CoreGraphics)
    /// The frame as an image, ready to draw. Expect it to look blocky — these are small panels.
    public func makeImage() -> CGImage? {
        guard bytesPerPixel >= 1 else { return nil }

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
