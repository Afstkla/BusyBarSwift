import Foundation

/// A bar found on the network or over the air, whichever way it turned up.
public struct DiscoveredDevice: Sendable, Identifiable, Hashable {
    public enum Route: Sendable, Hashable {
        case bluetooth(UUID)
        /// An IP address or hostname, reached over USB ethernet or Wi-Fi.
        case network(String)
    }

    public let id: String
    public let name: String
    public let route: Route
    /// Signal strength in dBm, for Bluetooth results only.
    public let rssi: Int?

    public var isBluetooth: Bool {
        if case .bluetooth = route { return true }
        return false
    }

    /// USB ethernet hands out `10.0.4.x`, so anything else came in over Wi-Fi.
    public var isOverUSB: Bool {
        if case let .network(host) = route { return host.hasPrefix("10.0.4.") }
        return false
    }

    /// How the device was reached, for display: `Bluetooth · -54 dBm`, `USB · 10.0.4.20`.
    public var routeDescription: String {
        switch route {
        case .bluetooth:
            "Bluetooth" + (rssi.map { " · \($0) dBm" } ?? "")
        case let .network(host):
            (isOverUSB ? "USB · " : "Wi-Fi · ") + host
        }
    }
}

extension BusyBarClient {
    /// Looks for bars over Bluetooth and Bonjour at the same time.
    ///
    /// A bar with Bluetooth enabled and a network connection appears once per route; the two
    /// entries cannot be matched up without talking to the device, so both are returned.
    public static func discover(for duration: TimeInterval = 3) async throws -> [DiscoveredDevice] {
        #if canImport(CoreBluetooth)
        async let bluetooth = (try? await BLETransport.scan(for: duration)) ?? []
        #endif
        #if canImport(Network)
        async let network = (try? await BonjourDiscovery.scan(for: duration)) ?? []
        #endif

        var devices: [DiscoveredDevice] = []

        #if canImport(CoreBluetooth)
        devices += await bluetooth.map {
            DiscoveredDevice(
                id: "ble:\($0.id)",
                name: $0.name,
                route: .bluetooth($0.id),
                rssi: $0.rssi
            )
        }
        #endif
        #if canImport(Network)
        devices += await network.map {
            DiscoveredDevice(
                id: "net:\($0.host)",
                name: $0.name,
                route: .network($0.host),
                rssi: nil
            )
        }
        #endif

        return devices
    }

    /// Builds a client for a discovered device.
    ///
    /// - Parameter fallback: another discovery result to fall back to when the primary route
    ///   fails — typically the network entry behind a Bluetooth one.
    public static func connect(
        to device: DiscoveredDevice,
        fallback: DiscoveredDevice? = nil,
        accessKey: String? = nil,
        applicationName: String = "busybar-swift"
    ) -> BusyBarClient {
        let transports = [device, fallback]
            .compactMap { $0 }
            .map { transport(for: $0, accessKey: accessKey) }

        return BusyBarClient(
            transport: transports.count == 1 ? transports[0] : FallbackTransport(transports),
            applicationName: applicationName
        )
    }

    private static func transport(
        for device: DiscoveredDevice,
        accessKey: String?
    ) -> BusyTransport {
        switch device.route {
        case let .network(host):
            HTTPTransport(host: host, accessKey: accessKey)
        case let .bluetooth(id):
            #if canImport(CoreBluetooth)
            BLETransport(deviceID: id, accessKey: accessKey)
            #else
            preconditionFailure("Bluetooth routes require CoreBluetooth")
            #endif
        }
    }
}
