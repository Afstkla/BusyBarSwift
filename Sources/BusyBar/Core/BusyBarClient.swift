import Foundation

/// A BUSY Bar you can talk to.
///
/// The client is transport-agnostic: the same calls go over Bluetooth, over your network,
/// or through BUSY Cloud depending on how you build it.
///
/// ```swift
/// let bar = try await BusyBarClient.nearby()
/// try await bar.draw(text: "Hello", for: "my_app")
/// ```
public struct BusyBarClient: Sendable {
    public let transport: BusyTransport

    /// Identifies your app to the bar. It scopes uploaded assets and decides whose
    /// display elements a clear call removes.
    public var applicationName: String

    private static let apiVersion = "25.0.0"

    public init(transport: BusyTransport, applicationName: String = "busybar-swift") {
        self.transport = transport
        self.applicationName = applicationName
    }

    #if canImport(CoreBluetooth)
    /// Connects over Bluetooth to whichever bar is answering loudest.
    ///
    /// Use ``discover(for:)`` and ``connect(to:fallback:accessKey:applicationName:)`` when you
    /// need to choose a specific bar or arrange a fallback route.
    public static func nearby(
        accessKey: String? = nil,
        applicationName: String = "busybar-swift"
    ) -> BusyBarClient {
        BusyBarClient(
            transport: BLETransport(accessKey: accessKey),
            applicationName: applicationName
        )
    }
    #endif

    /// Connects to a bar at a known address — `10.0.4.20` over USB, or its Wi-Fi address.
    public static func at(
        _ host: String,
        accessKey: String? = nil,
        applicationName: String = "busybar-swift"
    ) -> BusyBarClient {
        BusyBarClient(
            transport: HTTPTransport(host: host, accessKey: accessKey),
            applicationName: applicationName
        )
    }

    /// Connects through BUSY Cloud using a BAR-scope token.
    public static func cloud(
        token: String,
        applicationName: String = "busybar-swift"
    ) -> BusyBarClient {
        BusyBarClient(
            transport: HTTPTransport(cloudToken: token),
            applicationName: applicationName
        )
    }

    // MARK: - Plumbing

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    @discardableResult
    func perform(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> BusyResponse {
        var headers = ["X-Busy-Api-Version": Self.apiVersion]
        if let contentType {
            headers["Content-Type"] = contentType
        }

        let response = try await transport.send(
            BusyRequest(method: method, path: path, query: query, headers: headers, body: body)
        )

        guard (200..<300).contains(response.status) else {
            let decoded = try? Self.decoder.decode(APIErrorBody.self, from: response.body)
            let message = decoded?.error
                ?? String(data: response.body, encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 }
                ?? "no detail"
            throw BusyBarError.api(status: response.status, message: message, code: decoded?.code)
        }
        return response
    }

    func decode<T: Decodable>(
        _ type: T.Type,
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> T {
        let response = try await perform(method, path, query: query, body: body, contentType: contentType)
        do {
            return try Self.decoder.decode(type, from: response.body)
        } catch {
            throw BusyBarError.decoding("\(type) from \(path): \(error)")
        }
    }

    func send<Body: Encodable>(
        _ method: String,
        _ path: String,
        json: Body,
        query: [String: String] = [:]
    ) async throws {
        let data = try Self.encoder.encode(json)
        try await perform(method, path, query: query, body: data, contentType: "application/json")
    }
}
