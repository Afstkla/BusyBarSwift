import Foundation

public enum BusyBarError: Error, Sendable {
    case api(status: Int, message: String, code: Int?)
    case decoding(String)
    case malformedResponse(String)
    case bluetoothUnavailable(String)
    case deviceNotFound
    case notConnected
    case requestInFlight
    case timedOut
    case allTransportsFailed([Error])
}

extension BusyBarError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .api(status, message, code):
            let suffix = code.map { " (code \($0))" } ?? ""
            return "BUSY Bar returned HTTP \(status): \(message)\(suffix)"
        case let .decoding(detail):
            return "Could not decode the response: \(detail)"
        case let .malformedResponse(detail):
            return "Malformed HTTP response: \(detail)"
        case let .bluetoothUnavailable(detail):
            return "Bluetooth unavailable: \(detail)"
        case .deviceNotFound:
            return "No BUSY Bar found."
        case .notConnected:
            return "Not connected to a BUSY Bar."
        case .requestInFlight:
            return "Another request is already on the wire."
        case .timedOut:
            return "The BUSY Bar did not respond in time."
        case let .allTransportsFailed(errors):
            let detail = errors.map(\.localizedDescription).joined(separator: "; ")
            return "Every transport failed: \(detail)"
        }
    }
}

struct APIErrorBody: Decodable {
    let error: String
    let code: Int?
}
