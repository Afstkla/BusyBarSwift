import Foundation

extension BusyBarClient {
    /// Presses a key as though someone touched the bar.
    public func press(_ key: InputKey) async throws {
        try await perform("POST", "/input", query: ["key": key.rawValue])
    }

    public func httpAccess() async throws -> HTTPAccessInfo {
        try await decode(HTTPAccessInfo.self, "GET", "/access")
    }

    /// - Parameter key: 4–10 digits, required when `mode` is ``HTTPAccessMode/key``.
    public func setHTTPAccess(mode: HTTPAccessMode, key: String? = nil) async throws {
        var query = ["mode": mode.rawValue]
        if let key { query["key"] = key }
        try await perform("POST", "/access", query: query)
    }

    public func name() async throws -> String {
        try await decode(NameInfo.self, "GET", "/name").name
    }

    /// - Parameter name: up to 20 characters.
    public func setName(_ name: String) async throws {
        try await send("POST", "/name", json: NameInfo(name: name))
    }
}
