import Foundation

public enum InputKey: String, Sendable, Codable, CaseIterable {
    case up, down, ok, back, start, busy, custom, off, apps, settings
}

public enum HTTPAccessMode: String, Sendable, Codable {
    case disabled, enabled, key
}

public struct HTTPAccessInfo: Sendable, Decodable {
    public let mode: HTTPAccessMode
    public let keyValid: Bool?
}

public struct NameInfo: Sendable, Codable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

/// Either a fixed 0–100 level or the bar's ambient-light automatic mode.
public enum Brightness: Sendable, Equatable {
    case auto
    case level(Int)

    var wireValue: String {
        switch self {
        case .auto: "auto"
        case let .level(value): String(min(max(value, 0), 100))
        }
    }

    init(wireValue: String) {
        if wireValue == "auto" {
            self = .auto
        } else {
            self = .level(Int(wireValue) ?? 0)
        }
    }
}

struct BrightnessInfo: Decodable {
    let value: String
}

struct VolumeInfo: Decodable {
    let volume: Double
}

public struct SmartHomePairingInfo: Sendable, Decodable {
    public struct PairingStatus: Sendable, Decodable {
        public enum Value: String, Sendable, Decodable {
            case neverStarted = "never_started"
            case started
            case completedSuccessfully = "completed_successfully"
            case failed
        }

        public let value: Value
        public let timestamp: Int?
    }

    /// How many Matter fabrics the bar is commissioned into.
    public let fabricCount: Int
    public let latestPairingStatus: PairingStatus?
}

public struct SmartHomePairingPayload: Sendable, Decodable {
    /// Unix milliseconds, delivered as a string.
    public let availableUntil: String?
    public let qrCode: String?
    public let manualCode: String?
}

public struct SmartHomeSwitchState: Sendable, Codable {
    public enum Startup: String, Sendable, Codable {
        case off, on, toggle, last
    }

    public var state: Bool?
    /// Only ever sent to the device; the bar never reports it.
    public var startup: Startup?

    public init(state: Bool? = nil, startup: Startup? = nil) {
        self.state = state
        self.startup = startup
    }
}
