import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A single captured frame from one of the bar's displays.
///
/// The endpoint advertises `image/bmp`, but the body is base64-encoded raw pixels rather than a
/// BMP file — the front sends 3 bytes per pixel, the back 4.
public struct ScreenFrame: Sendable {
    public let screen: Screen
    public let width: Int
    public let height: Int
    public let pixels: Data

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
    public func pixel(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        let stride = bytesPerPixel
        guard stride >= 3, (0..<width).contains(x), (0..<height).contains(y) else { return nil }

        let offset = (y * width + x) * stride
        guard offset + 2 < pixels.count else { return nil }
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2])
    }

    #if canImport(CoreGraphics)
    /// The frame as an image, ready to draw. Expect it to look blocky — it is 72×16.
    public func makeImage() -> CGImage? {
        let stride = bytesPerPixel
        guard stride >= 3 else { return nil }

        var rgba = Data(capacity: width * height * 4)
        for index in 0..<(width * height) {
            let offset = index * stride
            guard offset + 2 < pixels.count else { break }
            rgba.append(pixels[offset])
            rgba.append(pixels[offset + 1])
            rgba.append(pixels[offset + 2])
            rgba.append(255)
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
