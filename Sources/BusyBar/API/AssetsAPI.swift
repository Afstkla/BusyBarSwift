import Foundation

extension BusyBarClient {
    /// Uploads a file into this app's asset directory, where `draw` and `playAudio` find it.
    public func uploadAsset(_ data: Data, as filename: String) async throws {
        try await perform(
            "POST",
            "/assets/upload",
            query: ["application_name": applicationName, "file": filename],
            body: data,
            contentType: "application/octet-stream"
        )
    }

    public func uploadAsset(contentsOf url: URL, as filename: String? = nil) async throws {
        let data = try Data(contentsOf: url)
        try await uploadAsset(data, as: filename ?? url.lastPathComponent)
    }

    /// Deletes every asset belonging to this app.
    public func deleteAssets() async throws {
        try await perform("DELETE", "/assets/upload", query: ["application_name": applicationName])
    }
}
