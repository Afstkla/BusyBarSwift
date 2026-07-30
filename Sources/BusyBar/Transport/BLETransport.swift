#if canImport(CoreBluetooth)
import Foundation

/// Carries the ordinary HTTP API over the firmware's Nordic UART bridge.
///
/// The device runs `ble_http_repeater`, which forwards whatever arrives on the UART
/// characteristics to its own web server on `127.0.0.1:80`. That makes BLE a byte pipe to
/// the same endpoints the IP transport uses, not a reduced command set.
public actor BLETransport: BusyTransport {
    private let link: BLELink
    private let deviceID: UUID?
    private let scanDuration: TimeInterval
    private let accessKey: String?
    private var inFlight: Task<BusyResponse, Error>?

    public init(
        deviceID: UUID? = nil,
        accessKey: String? = nil,
        scanDuration: TimeInterval = 3,
        responseTimeout: TimeInterval = 15
    ) {
        self.link = BLELink(responseTimeout: responseTimeout)
        self.deviceID = deviceID
        self.accessKey = accessKey
        self.scanDuration = scanDuration
    }

    /// Lists bars in range without connecting to any of them.
    public static func scan(for duration: TimeInterval = 3) async throws -> [DiscoveredBar] {
        try await BLELink(responseTimeout: duration).scan(duration: duration)
    }

    /// Releases the radio. The next request reconnects.
    public func disconnect() {
        link.disconnect()
    }

    /// Requests are queued so that only one is on the wire at a time — the repeater keeps a
    /// single loopback connection and interleaving would corrupt both responses.
    public func send(_ request: BusyRequest) async throws -> BusyResponse {
        let previous = inFlight
        let task = Task {
            _ = try? await previous?.value
            return try await perform(request)
        }
        inFlight = task
        return try await task.value
    }

    private func perform(_ request: BusyRequest) async throws -> BusyResponse {
        try await link.connect(to: deviceID, scanDuration: scanDuration)

        var request = request
        request.path = "/api" + request.path
        if let accessKey {
            request.headers["X-API-Token"] = accessKey
        }

        // The completeness check already builds the response, so it keeps it rather than
        // making us parse the same bytes a second time.
        let parsed = LockedBox<BusyResponse>()
        try await link.exchange(HTTPCodec.serialize(request, host: "127.0.0.1")) { buffer in
            guard let response = try HTTPCodec.parse(buffer) else { return false }
            parsed.store(response)
            return true
        }

        guard let response = parsed.take() else {
            throw BusyBarError.malformedResponse("the response ended before it was complete")
        }
        return response
    }
}
#endif
