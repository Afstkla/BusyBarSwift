import Foundation

/// A colour in the `#RRGGBBAA` form the display API expects.
public struct BusyColor: Sendable, Hashable, Encodable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Accepts `RGB`, `RRGGBB`, or `RRGGBBAA`, with or without a leading `#`.
    public init?(hex: String) {
        var text = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        if text.count == 6 {
            text += "FF"
        }
        guard text.count == 8, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red: UInt8((value >> 24) & 0xFF),
            green: UInt8((value >> 16) & 0xFF),
            blue: UInt8((value >> 8) & 0xFF),
            alpha: UInt8(value & 0xFF)
        )
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }

    public static let white = BusyColor(red: 255, green: 255, blue: 255)
    public static let black = BusyColor(red: 0, green: 0, blue: 0)
    public static let red = BusyColor(red: 255, green: 0, blue: 0)
    public static let green = BusyColor(red: 0, green: 255, blue: 0)
    public static let blue = BusyColor(red: 0, green: 0, blue: 255)
    public static let yellow = BusyColor(red: 255, green: 255, blue: 0)
    public static let cyan = BusyColor(red: 0, green: 255, blue: 255)
    public static let magenta = BusyColor(red: 255, green: 0, blue: 255)
    public static let orange = BusyColor(red: 255, green: 140, blue: 0)
    public static let clear = BusyColor(red: 0, green: 0, blue: 0, alpha: 0)
}
