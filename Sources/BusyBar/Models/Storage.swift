import Foundation

public struct StorageEntry: Sendable, Decodable {
    public enum Kind: String, Sendable, Decodable {
        case file, dir
    }

    public let type: Kind
    public let name: String
    /// Bytes, present for files only.
    public let size: Int?

    public var isDirectory: Bool { type == .dir }
}

struct StorageListResponse: Decodable {
    let list: [StorageEntry]
}

public struct StorageStatus: Sendable, Decodable {
    public let usedBytes: Int
    public let freeBytes: Int
    public let totalBytes: Int
}
