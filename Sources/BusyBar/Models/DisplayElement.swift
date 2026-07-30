import Foundation

public enum Screen: String, Sendable, Codable {
    case front, back

    /// Display elements name the screen, but `/screen` numbers it.
    public var wireIndex: Int {
        switch self {
        case .front: 0
        case .back: 1
        }
    }

    public var pixelWidth: Int {
        switch self {
        case .front: 72
        case .back: 40
        }
    }

    // ponytail: both sizes are measured from the frames /screen returns — the front is certain
    // (3456 bytes = 72x16 RGB), the back inferred (6400 bytes = 1600 pixels RGBA). Correct these
    // if a device ever reports otherwise.
    public var pixelHeight: Int {
        switch self {
        case .front: 16
        case .back: 40
        }
    }
}

extension Align {
    /// Where this anchor sits on `screen`.
    ///
    /// `align` only names *which point of the element* is being positioned; `x`/`y` still decide
    /// where that point lands, and both default to zero. Centring something therefore means
    /// asking for the centre anchor *and* putting it at the middle of the display.
    public func anchor(on screen: Screen) -> (x: Int, y: Int) {
        let width = screen.pixelWidth
        let height = screen.pixelHeight

        let x = switch self {
        case .topLeft, .midLeft, .bottomLeft: 0
        case .topMid, .center, .bottomMid: width / 2
        case .topRight, .midRight, .bottomRight: width
        }

        let y = switch self {
        case .topLeft, .topMid, .topRight: 0
        case .midLeft, .center, .midRight: height / 2
        case .bottomLeft, .bottomMid, .bottomRight: height
        }

        return (x, y)
    }
}

public enum Align: String, Sendable, Codable {
    case topLeft = "top_left"
    case topMid = "top_mid"
    case topRight = "top_right"
    case midLeft = "mid_left"
    case center
    case midRight = "mid_right"
    case bottomLeft = "bottom_left"
    case bottomMid = "bottom_mid"
    case bottomRight = "bottom_right"
}

public enum BusyFont: String, Sendable, Codable {
    case tiny, small, normal, condensed, bold, large
    case extraLarge = "extra_large"
    case global
}

public enum CountdownDirection: String, Sendable, Codable {
    case timeLeft = "time_left"
    case timeSince = "time_since"
}

public enum ShowHours: String, Sendable, Codable {
    case whenNonZero = "when_non_zero"
    case always
}

public enum RectangleFill: String, Sendable, Codable {
    case none, solid
    case gradientHorizontal = "gradient_h"
    case gradientVertical = "gradient_v"
}

/// One thing drawn on one of the bar's two screens.
public struct DisplayElement: Sendable, Encodable {
    public var id: String
    /// Seconds to keep the element on screen. Zero means indefinitely.
    public var timeout: Int?
    /// Unix timestamp at which to hide the element. Mutually exclusive with `timeout`.
    public var displayUntil: String?
    public var x: Int?
    public var y: Int?
    public var display: Screen?
    public var align: Align?
    public var content: Content

    public init(
        id: String,
        content: Content,
        x: Int? = nil,
        y: Int? = nil,
        display: Screen? = nil,
        align: Align? = nil,
        timeout: Int? = nil,
        displayUntil: String? = nil
    ) {
        self.id = id
        self.content = content
        self.x = x
        self.y = y
        self.display = display
        self.align = align
        self.timeout = timeout
        self.displayUntil = displayUntil
    }

    public enum Content: Sendable {
        case text(Text)
        case image(Image)
        case animation(Animation)
        case countdown(Countdown)
        case rectangle(Rectangle)

        var type: String {
            switch self {
            case .text: "text"
            case .image: "image"
            case .animation: "animation"
            case .countdown: "countdown"
            case .rectangle: "rectangle"
            }
        }
    }

    public struct Text: Sendable, Encodable {
        /// Printable ASCII only — the device's fonts are bitmap ASCII.
        public var text: String
        public var font: BusyFont
        public var color: BusyColor?
        public var width: Int?
        /// Pixels per minute.
        public var scrollRate: Int?
        public var scrollStartDelay: Int?
        public var scrollRepeatDelay: Int?

        public init(
            text: String,
            font: BusyFont = .normal,
            color: BusyColor? = nil,
            width: Int? = nil,
            scrollRate: Int? = nil,
            scrollStartDelay: Int? = nil,
            scrollRepeatDelay: Int? = nil
        ) {
            self.text = text
            self.font = font
            self.color = color
            self.width = width
            self.scrollRate = scrollRate
            self.scrollStartDelay = scrollStartDelay
            self.scrollRepeatDelay = scrollRepeatDelay
        }
    }

    public struct Image: Sendable, Encodable {
        /// A file uploaded under the app's own assets.
        public var path: String?
        /// A built-in asset, e.g. `shared/heart.png`.
        public var stockPath: String?
        public var opacity: Int?

        public init(path: String? = nil, stockPath: String? = nil, opacity: Int? = nil) {
            self.path = path
            self.stockPath = stockPath
            self.opacity = opacity
        }
    }

    public struct Animation: Sendable, Encodable {
        public var path: String?
        public var stockPath: String?
        public var loop: Bool?
        public var awaitPreviousEnd: Bool?
        /// `default` plays the whole animation.
        public var section: String?
        public var opacity: Int?

        public init(
            path: String? = nil,
            stockPath: String? = nil,
            loop: Bool? = nil,
            awaitPreviousEnd: Bool? = nil,
            section: String? = nil,
            opacity: Int? = nil
        ) {
            self.path = path
            self.stockPath = stockPath
            self.loop = loop
            self.awaitPreviousEnd = awaitPreviousEnd
            self.section = section
            self.opacity = opacity
        }
    }

    public struct Countdown: Sendable, Encodable {
        /// The API takes this Unix timestamp as a string, not a number.
        public var timestamp: String
        public var direction: CountdownDirection
        public var showHours: ShowHours
        public var color: BusyColor?

        public init(
            timestamp: String,
            direction: CountdownDirection = .timeLeft,
            showHours: ShowHours = .whenNonZero,
            color: BusyColor? = nil
        ) {
            self.timestamp = timestamp
            self.direction = direction
            self.showHours = showHours
            self.color = color
        }

        public init(
            until date: Date,
            direction: CountdownDirection = .timeLeft,
            showHours: ShowHours = .whenNonZero,
            color: BusyColor? = nil
        ) {
            self.init(
                timestamp: String(Int(date.timeIntervalSince1970)),
                direction: direction,
                showHours: showHours,
                color: color
            )
        }
    }

    public struct Rectangle: Sendable, Encodable {
        public var width: Int
        public var height: Int
        public var radius: Int?
        public var fill: RectangleFill?
        /// One colour for a solid fill, two for a gradient.
        public var fillColors: [BusyColor]?
        public var borderWidth: Int?
        public var borderColor: BusyColor?

        public init(
            width: Int,
            height: Int,
            radius: Int? = nil,
            fill: RectangleFill? = nil,
            fillColors: [BusyColor]? = nil,
            borderWidth: Int? = nil,
            borderColor: BusyColor? = nil
        ) {
            self.width = width
            self.height = height
            self.radius = radius
            self.fill = fill
            self.fillColors = fillColors
            self.borderWidth = borderWidth
            self.borderColor = borderColor
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(id, forKey: "id")
        try container.encode(content.type, forKey: "type")
        try container.encodeIfPresent(timeout, forKey: "timeout")
        try container.encodeIfPresent(displayUntil, forKey: "displayUntil")
        try container.encodeIfPresent(x, forKey: "x")
        try container.encodeIfPresent(y, forKey: "y")
        try container.encodeIfPresent(display, forKey: "display")
        try container.encodeIfPresent(align, forKey: "align")

        // Each payload encodes into this same object, flattening its fields alongside `type`.
        switch content {
        case let .text(payload): try payload.encode(to: encoder)
        case let .image(payload): try payload.encode(to: encoder)
        case let .animation(payload): try payload.encode(to: encoder)
        case let .countdown(payload): try payload.encode(to: encoder)
        case let .rectangle(payload): try payload.encode(to: encoder)
        }
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}

extension DynamicCodingKey: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self.init(stringValue: value) }
}

// MARK: - Shorthand

extension DisplayElement {
    public static func text(
        _ text: String,
        id: String = "text",
        font: BusyFont = .normal,
        color: BusyColor? = nil,
        x: Int? = nil,
        y: Int? = nil,
        display: Screen? = nil,
        align: Align? = nil,
        timeout: Int? = nil
    ) -> DisplayElement {
        DisplayElement(
            id: id,
            content: .text(Text(text: text, font: font, color: color)),
            x: x,
            y: y,
            display: display,
            align: align,
            timeout: timeout
        )
    }

    public static func image(
        path: String,
        id: String = "image",
        x: Int? = nil,
        y: Int? = nil,
        display: Screen? = nil,
        timeout: Int? = nil
    ) -> DisplayElement {
        DisplayElement(
            id: id,
            content: .image(Image(path: path)),
            x: x,
            y: y,
            display: display,
            timeout: timeout
        )
    }

    public static func countdown(
        until date: Date,
        id: String = "countdown",
        color: BusyColor? = nil,
        x: Int? = nil,
        y: Int? = nil,
        display: Screen? = nil,
        align: Align? = nil
    ) -> DisplayElement {
        DisplayElement(
            id: id,
            content: .countdown(Countdown(until: date, color: color)),
            x: x,
            y: y,
            display: display,
            align: align
        )
    }
}

/// A full draw request: which app is drawing, at what priority, and what to put on screen.
public struct DrawRequest: Sendable, Encodable {
    public var applicationName: String
    /// 1–100. The bar accepts a draw when this is at least the running app's priority:
    /// built-in apps sit at 10, an active BUSY session at 90.
    public var priority: Int?
    public var ledNotificationColor: BusyColor?
    public var elements: [DisplayElement]

    public init(
        applicationName: String,
        elements: [DisplayElement],
        priority: Int? = nil,
        ledNotificationColor: BusyColor? = nil
    ) {
        self.applicationName = applicationName
        self.elements = elements
        self.priority = priority
        self.ledNotificationColor = ledNotificationColor
    }
}
