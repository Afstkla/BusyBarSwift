import Foundation

public struct UpdateStatus: Sendable, Decodable {
    public struct Install: Sendable, Decodable {
        public enum Event: String, Sendable, Decodable {
            case sessionStart = "session_start"
            case sessionStop = "session_stop"
            case actionBegin = "action_begin"
            case actionDone = "action_done"
            case detailChange = "detail_change"
            case actionProgress = "action_progress"
            case none
        }

        public enum Action: String, Sendable, Decodable {
            case download
            case shaVerification = "sha_verification"
            case unpack
            case prepare
            case apply
            case none
        }

        public struct Download: Sendable, Decodable {
            public let speedBytesPerSec: Int?
            public let receivedBytes: Int?
            public let totalBytes: Int?
        }

        /// False when the battery is too low to install safely.
        public let isAllowed: Bool?
        public let event: Event?
        public let action: Action?
        /// Left as a string: the firmware's failure list grows between releases, and an
        /// unrecognised value should not fail the whole decode.
        public let status: String?
        public let detail: String?
        public let download: Download?
    }

    public struct Check: Sendable, Decodable {
        public enum Event: String, Sendable, Decodable {
            case start, stop, none
        }

        public enum Status: String, Sendable, Decodable {
            case available
            case notAvailable = "not_available"
            case failure
            case none
        }

        /// Empty when no update is waiting.
        public let availableVersion: String?
        public let event: Event?
        public let status: Status?
    }

    public let install: Install?
    public let check: Check?
}

public struct AutoupdateSettings: Sendable, Codable {
    public var isEnabled: Bool?
    /// `HH:MM`.
    public var intervalStart: String?
    /// `HH:MM`.
    public var intervalEnd: String?

    public init(isEnabled: Bool? = nil, intervalStart: String? = nil, intervalEnd: String? = nil) {
        self.isEnabled = isEnabled
        self.intervalStart = intervalStart
        self.intervalEnd = intervalEnd
    }
}

struct ChangelogResponse: Decodable {
    let changelog: String?
}
