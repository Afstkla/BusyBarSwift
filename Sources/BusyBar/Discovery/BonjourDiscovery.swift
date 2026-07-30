#if canImport(Network)
import Foundation
import Network

public struct NetworkBar: Sendable, Hashable {
    public let name: String
    public let host: String
    /// USB ethernet hands out `10.0.4.x`, so anything else arrived over Wi-Fi.
    public var isOverUSB: Bool { host.hasPrefix("10.0.4.") }
}

/// Finds bars advertising `_busybar._tcp` on the local network.
public enum BonjourDiscovery {
    public static func scan(for duration: TimeInterval = 2) async throws -> [NetworkBar] {
        let browser = NWBrowser(for: .bonjour(type: "_busybar._tcp", domain: nil), using: .tcp)

        let endpoints: [NWEndpoint] = await withCheckedContinuation { continuation in
            let box = ContinuationBox(continuation)
            browser.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + duration) {
                let found = browser.browseResults.map(\.endpoint)
                browser.cancel()
                box.resume(with: found)
            }
        }

        return await withTaskGroup(of: NetworkBar?.self) { group in
            for endpoint in endpoints {
                guard case let .service(name, _, _, _) = endpoint else { continue }
                group.addTask {
                    guard let host = await resolve(endpoint) else { return nil }
                    return NetworkBar(name: name, host: host)
                }
            }
            var bars: [NetworkBar] = []
            for await bar in group {
                if let bar { bars.append(bar) }
            }
            return bars.sorted { $0.host < $1.host }
        }
    }

    /// Bonjour hands back a service name; opening a connection is what turns it into an address.
    private static func resolve(_ endpoint: NWEndpoint, timeout: TimeInterval = 2) async -> String? {
        await withCheckedContinuation { continuation in
            let box = ContinuationBox(continuation)
            let connection = NWConnection(to: endpoint, using: .tcp)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard case let .hostPort(host, _)? = connection.currentPath?.remoteEndpoint else {
                        connection.cancel()
                        box.resume(with: nil)
                        return
                    }
                    connection.cancel()
                    // Strip the interface scope an IPv6 literal carries, e.g. "fe80::1%en0".
                    box.resume(with: "\(host)".components(separatedBy: "%").first)
                case .failed, .cancelled:
                    box.resume(with: nil)
                default:
                    break
                }
            }

            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                box.resume(with: nil)
            }
        }
    }
}

/// Resumes a continuation exactly once, however many callbacks race to finish it.
private struct ContinuationBox<Value: Sendable>: Sendable {
    private let box: LockedBox<CheckedContinuation<Value, Never>>

    init(_ continuation: CheckedContinuation<Value, Never>) {
        box = LockedBox(continuation)
    }

    func resume(with value: Value) {
        box.claim()?.resume(returning: value)
    }
}
#endif
