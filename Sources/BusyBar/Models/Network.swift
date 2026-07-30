import Foundation

public struct BLEStatus: Sendable, Decodable {
    public enum State: String, Sendable, Decodable {
        case reset
        case initialization
        case disabled
        case enabled
        case connectable
        case connected
        case internalError = "internal error"
    }

    public let status: State
    /// Present only while connected.
    public let address: String?
}

public enum WifiSecurity: String, Sendable, Decodable {
    case open = "Open"
    case wpa = "WPA"
    case wpa2 = "WPA2"
    case wep = "WEP"
    case wpaWpa2 = "WPA/WPA2"
    case wpa3 = "WPA3"
    case wpa2Wpa3 = "WPA2/WPA3"
    case unsupported = "Unsupported"
}

public enum WifiIPMethod: String, Sendable, Decodable {
    case dhcp, `static`
}

public enum WifiIPType: String, Sendable, Decodable {
    case ipv4, ipv6
}

public struct WifiIPConfig: Sendable, Decodable {
    public let ipMethod: WifiIPMethod?
    public let ipType: WifiIPType?
    public let address: String?
}

public struct WifiStatus: Sendable, Decodable {
    public enum State: String, Sendable, Decodable {
        case unknown, disconnected, connected, connecting, disconnecting, reconnecting
    }

    public let state: State
    public let ssid: String?
    public let bssid: String?
    public let channel: Int?
    public let rssi: Int?
    public let security: WifiSecurity?
    public let ipConfig: WifiIPConfig?
}

public struct AccountInfo: Sendable, Decodable {
    public let linked: Bool?
    public let id: String?
    public let email: String?
    public let userId: String?
}

public struct AccountStatus: Sendable, Decodable {
    public enum State: String, Sendable, Decodable {
        case error, disconnected, connected
    }

    public let status: State?
}

public struct AccountBackend: Sendable, Decodable {
    public enum CertificateType: String, Sendable, Decodable {
        case `default`, custom, none
    }

    public let serverUrl: String
    public let clientCertType: CertificateType
    public let ignoreServerCert: Bool
}
