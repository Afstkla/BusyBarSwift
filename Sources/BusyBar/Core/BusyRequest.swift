import Foundation

public struct BusyRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    public var headers: [String: String]
    public var body: Data?

    public init(
        method: String,
        path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }

    /// The request-line target: path plus a percent-encoded, order-stable query.
    public var pathWithQuery: String {
        guard !query.isEmpty else { return path }
        var components = URLComponents()
        components.queryItems = query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return "\(path)?\(components.percentEncodedQuery ?? "")"
    }
}

public struct BusyResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public protocol BusyTransport: Sendable {
    func send(_ request: BusyRequest) async throws -> BusyResponse
}
