import Foundation

/// A value handed between a framework callback queue and an awaiting caller.
///
/// `Mutex` would be the modern choice, but it needs macOS 15 and this package supports 14.
final class LockedBox<Value: Sendable>: @unchecked Sendable {
    private var value: Value?
    private let lock = NSLock()

    init(_ value: Value? = nil) {
        self.value = value
    }

    func store(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    func take() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    /// Removes and returns the value, so only the first caller gets it.
    func claim() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        let claimed = value
        value = nil
        return claimed
    }
}
