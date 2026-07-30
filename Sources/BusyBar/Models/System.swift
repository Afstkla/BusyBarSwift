import Foundation

public struct VersionInfo: Sendable, Decodable {
    public let apiSemver: String
}

public struct NetworkInterfaceInfo: Sendable, Decodable {
    public enum Kind: String, Sendable, Decodable {
        case usb, wifi
    }
    public let type: Kind
}

public struct DeviceStatus: Sendable, Decodable {
    public let device: DeviceInfo?
    public let firmware: FirmwareInfo?
    public let system: SystemInfo?
    public let power: PowerInfo?
}

public struct DeviceInfo: Sendable, Decodable {
    public enum FirmwareSecurity: String, Sendable, Decodable {
        case secure, insecure, other, unknown
    }

    public let serialNumber: String
    public let usbMac: String
    public let wifiMac: String?
    public let bleMac: String?
    public let otpValid: Bool
    public let otpModel: String?
    public let otpTimestamp: Int?
    public let firmwareSecurity: FirmwareSecurity
}

public struct FirmwareInfo: Sendable, Decodable {
    public let version: String
    public let target: Int
    public let branch: String
    public let buildDate: String
    public let commitHash: String
    public let intercomVersion: String
    public let nwpVersion: String?
    public let matterVersion: String?
}

public struct SystemInfo: Sendable, Decodable {
    public let apiSemver: String
    public let uptime: String
    public let bootTime: Int
    public let autoUpdateEnabled: Bool
}

public struct PowerInfo: Sendable, Decodable {
    public enum State: String, Sendable, Decodable {
        case discharging, charging, charged
    }

    public let state: State
    /// Percent.
    public let batteryCharge: Int
    /// Millivolts.
    public let batteryVoltage: Int
    /// Milliamps; negative while discharging.
    public let batteryCurrent: Int
    /// Millivolts.
    public let usbVoltage: Int
}

public struct TimestampInfo: Sendable, Decodable {
    /// ISO 8601 with a timezone qualifier.
    public let timestamp: String
}

public struct TimezoneInfo: Sendable, Decodable {
    public let name: String
    public let offset: String
    public let abbr: String
}

struct TimezoneListResponse: Decodable {
    let list: [TimezoneInfo]
}

public struct LogDumpResult: Sendable, Decodable {
    /// Where on the device the log was written, e.g. `/ext/log.txt`.
    public let path: String
}
