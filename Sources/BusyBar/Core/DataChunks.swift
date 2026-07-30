import Foundation

extension Data {
    /// Splits into pieces of at most `size` bytes, the way a BLE write or indication carries them.
    func chunks(of size: Int) -> [Data] {
        precondition(size > 0, "chunk size must be positive")
        return stride(from: 0, to: count, by: size).map { offset in
            Data(self[index(startIndex, offsetBy: offset)..<index(startIndex, offsetBy: Swift.min(offset + size, count))])
        }
    }
}
