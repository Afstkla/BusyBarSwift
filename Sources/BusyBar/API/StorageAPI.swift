import Foundation

/// File operations on the bar's internal storage. Every path lives under `/ext`.
extension BusyBarClient {
    public func listStorage(at path: String = "/ext") async throws -> [StorageEntry] {
        try await decode(StorageListResponse.self, "GET", "/storage/list", query: ["path": path]).list
    }

    public func readFile(at path: String) async throws -> Data {
        try await perform("GET", "/storage/read", query: ["path": path]).body
    }

    public func writeFile(_ data: Data, to path: String) async throws {
        try await perform(
            "POST",
            "/storage/write",
            query: ["path": path],
            body: data,
            contentType: "application/octet-stream"
        )
    }

    public func removeFile(at path: String) async throws {
        try await perform("DELETE", "/storage/remove", query: ["path": path])
    }

    public func createDirectory(at path: String) async throws {
        try await perform("POST", "/storage/mkdir", query: ["path": path])
    }

    public func moveFile(from path: String, to newPath: String) async throws {
        try await perform("POST", "/storage/rename", query: ["path": path, "new_path": newPath])
    }

    public func storageStatus() async throws -> StorageStatus {
        try await decode(StorageStatus.self, "GET", "/storage/status")
    }
}
