import Foundation

/// Tries each transport in order and sticks with the first one that answers.
///
/// The usual arrangement is BLE first with an IP transport behind it, so a bar that is
/// out of Bluetooth range — or that has its BLE radio switched off — still works over Wi-Fi.
public actor FallbackTransport: BusyTransport {
    private let transports: [BusyTransport]
    private var preferred = 0

    public init(_ transports: [BusyTransport]) {
        precondition(!transports.isEmpty, "FallbackTransport needs at least one transport")
        self.transports = transports
    }

    /// A transport that throws failed to deliver. One that returns — even a 409 — reached the
    /// bar, so its answer stands and no other transport is tried.
    public func send(_ request: BusyRequest) async throws -> BusyResponse {
        var failures: [Error] = []
        let order = Array(preferred..<transports.count) + Array(0..<preferred)

        for index in order {
            do {
                let response = try await transports[index].send(request)
                preferred = index
                return response
            } catch {
                failures.append(error)
            }
        }
        throw BusyBarError.allTransportsFailed(failures)
    }
}
