import Foundation

public enum BusyProfileSlot: String, Sendable, Codable {
    case busy, custom
}

public struct BusyBarSettings: Sendable, Codable {
    public var theme: String
    public var showWorkPhaseOnly: Bool
    public var triggerSmartHome: Bool

    public init(theme: String, showWorkPhaseOnly: Bool, triggerSmartHome: Bool) {
        self.theme = theme
        self.showWorkPhaseOnly = showWorkPhaseOnly
        self.triggerSmartHome = triggerSmartHome
    }
}

public struct IntervalSettings: Sendable, Codable {
    public var intervalWorkMs: Int
    public var intervalRestMs: Int
    public var intervalWorkCyclesCount: Int
    public var isAutostartEnabled: Bool

    public init(
        intervalWorkMs: Int,
        intervalRestMs: Int,
        intervalWorkCyclesCount: Int,
        isAutostartEnabled: Bool = false
    ) {
        self.intervalWorkMs = intervalWorkMs
        self.intervalRestMs = intervalRestMs
        self.intervalWorkCyclesCount = intervalWorkCyclesCount
        self.isAutostartEnabled = isAutostartEnabled
    }
}

/// How a profile's timer is configured.
public enum BusyTimerSettings: Sendable, Codable {
    case infinite
    case simple(totalTimeMs: Int)
    case interval(IntervalSettings)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let type = try container.decode(String.self, forKey: "type")
        switch type {
        case "INFINITE":
            self = .infinite
        case "SIMPLE":
            self = .simple(totalTimeMs: try container.decode(Int.self, forKey: "totalTimeMs"))
        case "INTERVAL":
            self = .interval(try IntervalSettings(from: decoder))
        default:
            throw BusyBarError.decoding("unknown timer type '\(type)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        switch self {
        case .infinite:
            try container.encode("INFINITE", forKey: "type")
        case let .simple(totalTimeMs):
            try container.encode("SIMPLE", forKey: "type")
            try container.encode(totalTimeMs, forKey: "totalTimeMs")
        case let .interval(settings):
            try container.encode("INTERVAL", forKey: "type")
            try settings.encode(to: encoder)
        }
    }
}

/// Where the timer currently stands.
public enum BusyTimerState: Sendable, Codable {
    case notStarted
    case infinite(cardID: String, isPaused: Bool)
    case simple(cardID: String, timeLeftMs: Int, isPaused: Bool)
    case interval(
        cardID: String,
        currentInterval: Int,
        currentIntervalTimeTotalMs: Int,
        currentIntervalTimeLeftMs: Int,
        isPaused: Bool,
        settings: IntervalSettings
    )

    public var isPaused: Bool {
        switch self {
        case .notStarted: false
        case let .infinite(_, isPaused): isPaused
        case let .simple(_, _, isPaused): isPaused
        case let .interval(_, _, _, _, isPaused, _): isPaused
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let type = try container.decode(String.self, forKey: "type")
        switch type {
        case "NOT_STARTED":
            self = .notStarted
        case "INFINITE":
            self = .infinite(
                cardID: try container.decode(String.self, forKey: "cardId"),
                isPaused: try container.decode(Bool.self, forKey: "isPaused")
            )
        case "SIMPLE":
            self = .simple(
                cardID: try container.decode(String.self, forKey: "cardId"),
                timeLeftMs: try container.decode(Int.self, forKey: "timeLeftMs"),
                isPaused: try container.decode(Bool.self, forKey: "isPaused")
            )
        case "INTERVAL":
            self = .interval(
                cardID: try container.decode(String.self, forKey: "cardId"),
                currentInterval: try container.decode(Int.self, forKey: "currentInterval"),
                currentIntervalTimeTotalMs: try container.decode(Int.self, forKey: "currentIntervalTimeTotalMs"),
                currentIntervalTimeLeftMs: try container.decode(Int.self, forKey: "currentIntervalTimeLeftMs"),
                isPaused: try container.decode(Bool.self, forKey: "isPaused"),
                settings: try container.decode(IntervalSettings.self, forKey: "intervalSettings")
            )
        default:
            throw BusyBarError.decoding("unknown snapshot type '\(type)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        switch self {
        case .notStarted:
            try container.encode("NOT_STARTED", forKey: "type")
        case let .infinite(cardID, isPaused):
            try container.encode("INFINITE", forKey: "type")
            try container.encode(cardID, forKey: "cardId")
            try container.encode(isPaused, forKey: "isPaused")
        case let .simple(cardID, timeLeftMs, isPaused):
            try container.encode("SIMPLE", forKey: "type")
            try container.encode(cardID, forKey: "cardId")
            try container.encode(timeLeftMs, forKey: "timeLeftMs")
            try container.encode(isPaused, forKey: "isPaused")
        case let .interval(cardID, current, total, left, isPaused, settings):
            try container.encode("INTERVAL", forKey: "type")
            try container.encode(cardID, forKey: "cardId")
            try container.encode(current, forKey: "currentInterval")
            try container.encode(total, forKey: "currentIntervalTimeTotalMs")
            try container.encode(left, forKey: "currentIntervalTimeLeftMs")
            try container.encode(isPaused, forKey: "isPaused")
            try container.encode(settings, forKey: "intervalSettings")
        }
    }
}

public struct BusySnapshotBody: Sendable, Codable {
    public var state: BusyTimerState
    public var busyBarSettings: BusyBarSettings

    public init(state: BusyTimerState, busyBarSettings: BusyBarSettings) {
        self.state = state
        self.busyBarSettings = busyBarSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        self.state = try BusyTimerState(from: decoder)
        self.busyBarSettings = try container.decode(BusyBarSettings.self, forKey: "busyBarSettings")
    }

    public func encode(to encoder: Encoder) throws {
        try state.encode(to: encoder)
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(busyBarSettings, forKey: "busyBarSettings")
    }
}

public struct BusySnapshot: Sendable, Codable {
    public var snapshot: BusySnapshotBody
    public var snapshotTimestampMs: Int

    public init(snapshot: BusySnapshotBody, snapshotTimestampMs: Int) {
        self.snapshot = snapshot
        self.snapshotTimestampMs = snapshotTimestampMs
    }
}

public struct BusyProfile: Sendable, Codable {
    public var id: String
    public var title: String
    public var sortOrder: Int
    public var timerSettings: BusyTimerSettings
    public var busyBarSettings: BusyBarSettings
    public var profileTimestampMs: Int

    public init(
        id: String,
        title: String,
        sortOrder: Int,
        timerSettings: BusyTimerSettings,
        busyBarSettings: BusyBarSettings,
        profileTimestampMs: Int
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.timerSettings = timerSettings
        self.busyBarSettings = busyBarSettings
        self.profileTimestampMs = profileTimestampMs
    }
}
