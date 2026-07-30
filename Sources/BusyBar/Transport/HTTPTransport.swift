import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to a bar reachable over IP — USB ethernet (`10.0.4.20`), Wi-Fi, or the cloud proxy.
public struct HTTPTransport: BusyTransport {
    public let baseURL: URL
    private let session: URLSession
    private let authHeader: (name: String, value: String)?
    private let pathPrefix: String

    /// - Parameter accessKey: the device's HTTP API access key, sent as `X-API-Token`.
    public init(host: String, accessKey: String? = nil, timeout: TimeInterval = 10) {
        let normalized = host.contains("://") ? host : "http://\(host)"
        self.baseURL = URL(string: normalized)!

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: configuration)
        self.authHeader = accessKey.map { (name: "X-API-Token", value: $0) }
        self.pathPrefix = "/api"
    }

    /// Talks to the bar through BUSY Cloud rather than over the local network.
    ///
    /// - Parameter token: a BUSY Cloud BAR-scope token, sent as `Authorization: Bearer`.
    public init(cloudToken: String, host: String = "https://api.busy.app", timeout: TimeInterval = 10) {
        self.baseURL = URL(string: host)!

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: configuration)
        self.authHeader = (name: "Authorization", value: "Bearer \(cloudToken)")
        // The cloud exposes the same endpoints one level along.
        self.pathPrefix = "/busybar"
    }

    public func send(_ request: BusyRequest) async throws -> BusyResponse {
        var request = request
        request.path = pathPrefix + request.path

        guard let url = URL(string: request.pathWithQuery, relativeTo: baseURL) else {
            throw BusyBarError.malformedResponse("could not build a URL for \(request.path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if let authHeader {
            urlRequest.setValue(authHeader.value, forHTTPHeaderField: authHeader.name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw BusyBarError.malformedResponse("response was not HTTP")
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key.lowercased()] = value
            }
        }
        return BusyResponse(status: http.statusCode, headers: headers, body: data)
    }
}
