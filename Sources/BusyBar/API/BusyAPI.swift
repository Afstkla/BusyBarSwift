import Foundation

extension BusyBarClient {
    /// The current state of the BUSY timer.
    public func busySnapshot() async throws -> BusySnapshot {
        try await decode(BusySnapshot.self, "GET", "/busy/snapshot")
    }

    /// Runs the timer from the given snapshot.
    public func setBusySnapshot(_ snapshot: BusySnapshot) async throws {
        try await send("PUT", "/busy/snapshot", json: snapshot)
    }

    public func busyProfile(slot: BusyProfileSlot) async throws -> BusyProfile {
        try await decode(BusyProfile.self, "GET", "/busy/profiles/\(slot.rawValue)")
    }

    public func setBusyProfile(_ profile: BusyProfile, slot: BusyProfileSlot) async throws {
        try await send("PUT", "/busy/profiles/\(slot.rawValue)", json: profile)
    }
}
