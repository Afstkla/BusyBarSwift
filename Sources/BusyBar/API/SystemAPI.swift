import Foundation

extension BusyBarClient {
    /// The API version the firmware implements.
    public func version() async throws -> VersionInfo {
        try await decode(VersionInfo.self, "GET", "/version")
    }

    /// Whether the bar is currently reachable over USB or Wi-Fi.
    public func networkInterface() async throws -> NetworkInterfaceInfo {
        try await decode(NetworkInterfaceInfo.self, "GET", "/transport")
    }

    public func status() async throws -> DeviceStatus {
        try await decode(DeviceStatus.self, "GET", "/status")
    }

    public func deviceInfo() async throws -> DeviceInfo {
        try await decode(DeviceInfo.self, "GET", "/status/device")
    }

    public func firmwareInfo() async throws -> FirmwareInfo {
        try await decode(FirmwareInfo.self, "GET", "/status/firmware")
    }

    public func systemInfo() async throws -> SystemInfo {
        try await decode(SystemInfo.self, "GET", "/status/system")
    }

    public func powerInfo() async throws -> PowerInfo {
        try await decode(PowerInfo.self, "GET", "/status/power")
    }

    /// Snapshots the in-memory log buffer to a file under `/ext`.
    @discardableResult
    public func dumpLog(filename: String? = nil) async throws -> LogDumpResult {
        let query = filename.map { ["filename": $0] } ?? [:]
        return try await decode(LogDumpResult.self, "POST", "/log_dump", query: query)
    }

    // MARK: - Time

    public func time() async throws -> TimestampInfo {
        try await decode(TimestampInfo.self, "GET", "/time")
    }

    /// The bar rejects a timestamp without a timezone qualifier; `.iso8601` always emits `Z`.
    public func setTime(_ date: Date = Date()) async throws {
        try await perform("POST", "/time/timestamp", query: ["timestamp": date.formatted(.iso8601)])
    }

    public func timezone() async throws -> TimezoneInfo {
        try await decode(TimezoneInfo.self, "GET", "/time/timezone")
    }

    /// - Parameter timezone: a name from ``supportedTimezones()``, e.g. `Berlin`.
    public func setTimezone(_ timezone: String) async throws {
        try await perform("POST", "/time/timezone", query: ["timezone": timezone])
    }

    public func supportedTimezones() async throws -> [TimezoneInfo] {
        try await decode(TimezoneListResponse.self, "GET", "/time/tzlist").list
    }
}
