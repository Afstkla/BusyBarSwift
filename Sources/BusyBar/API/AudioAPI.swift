import Foundation

extension BusyBarClient {
    /// Plays a `.snd` file previously uploaded to this app's assets.
    public func playAudio(path: String) async throws {
        try await send("POST", "/audio/play", json: PlayAudioBody(
            applicationName: applicationName,
            path: path,
            stockPath: nil
        ))
    }

    /// Plays one of the firmware's built-in sounds, e.g. `shared/beep.snd`.
    public func playStockAudio(_ stockPath: String) async throws {
        try await send("POST", "/audio/play", json: PlayAudioBody(
            applicationName: applicationName,
            path: nil,
            stockPath: stockPath
        ))
    }

    public func stopAudio() async throws {
        try await perform("DELETE", "/audio/play")
    }

    /// 0–100.
    public func volume() async throws -> Double {
        try await decode(VolumeInfo.self, "GET", "/audio/volume").volume
    }

    /// - Parameter silent: suppress the confirmation blip the bar normally plays.
    public func setVolume(_ volume: Double, silent: Bool = false) async throws {
        var query = ["volume": String(Int(volume.rounded()))]
        if silent { query["silent"] = "1" }
        try await perform("POST", "/audio/volume", query: query)
    }
}

struct PlayAudioBody: Encodable {
    let applicationName: String
    let path: String?
    let stockPath: String?
}
