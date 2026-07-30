import Foundation

extension BusyBarClient {
    /// Starts an asynchronous check for a newer firmware. Poll ``updateStatus()`` for the result.
    public func checkForUpdate() async throws {
        try await perform("POST", "/update/check")
    }

    public func updateStatus() async throws -> UpdateStatus {
        try await decode(UpdateStatus.self, "GET", "/update/status")
    }

    public func updateChangelog(version: String) async throws -> String? {
        try await decode(
            ChangelogResponse.self,
            "GET",
            "/update/changelog",
            query: ["version": version]
        ).changelog
    }

    /// Downloads and installs `version` in the background. The bar reboots when it finishes.
    public func installUpdate(version: String) async throws {
        try await perform("POST", "/update/install", query: ["version": version])
    }

    public func abortUpdateDownload() async throws {
        try await perform("POST", "/update/abort_download")
    }

    /// Uploads a firmware TAR directly instead of fetching one from BUSY's servers.
    public func uploadFirmware(_ data: Data) async throws {
        try await perform("POST", "/update", body: data, contentType: "application/octet-stream")
    }

    public func autoupdateSettings() async throws -> AutoupdateSettings {
        try await decode(AutoupdateSettings.self, "GET", "/update/autoupdate")
    }

    /// Only the fields you set are changed.
    public func setAutoupdateSettings(_ settings: AutoupdateSettings) async throws {
        try await send("POST", "/update/autoupdate", json: settings)
    }
}
