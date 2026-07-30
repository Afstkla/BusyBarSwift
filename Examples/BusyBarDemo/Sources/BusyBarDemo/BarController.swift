import BusyBar
import Foundation
import Observation

@MainActor
@Observable
final class BarController {
    enum Connection: Equatable {
        case disconnected
        case connecting
        case connected(via: String)
    }

    var connection: Connection = .disconnected
    var candidates: [DiscoveredDevice] = []
    var isScanning = false
    var status: DeviceStatus?
    var wifi: WifiStatus?
    var deviceName = ""
    var brightness: Brightness = .auto
    var volume: Double = 50
    var lastError: String?
    var frontFrame: ScreenFrame?
    var backFrame: ScreenFrame?
    var isMirroring = false

    private var client: BusyBarClient?
    private var refreshTask: Task<Void, Never>?

    func scan() async {
        isScanning = true
        lastError = nil
        defer { isScanning = false }

        candidates = (try? await BusyBarClient.discover()) ?? []
    }

    func connect(to device: DiscoveredDevice, accessKey: String?) async {
        // A bar reachable both ways gets its network entry as the backstop for Bluetooth.
        let fallback = device.isBluetooth ? candidates.first(where: { !$0.isBluetooth }) : nil

        await activate(
            BusyBarClient.connect(
                to: device,
                fallback: fallback,
                accessKey: accessKey.presence,
                applicationName: "swift_demo"
            ),
            via: device.routeDescription
        )
    }

    /// Connects straight to an address, skipping discovery.
    func connect(toHost host: String, accessKey: String?) async {
        await activate(
            BusyBarClient.at(host, accessKey: accessKey.presence, applicationName: "swift_demo"),
            via: "HTTP · \(host)"
        )
    }

    /// Reaches the bar through BUSY Cloud, wherever it is.
    func connectToCloud(token: String) async {
        await activate(
            BusyBarClient.cloud(token: token, applicationName: "swift_demo"),
            via: "BUSY Cloud"
        )
    }

    private func activate(_ candidate: BusyBarClient, via route: String) async {
        connection = .connecting
        lastError = nil
        client = candidate

        do {
            try await loadEverything()
            connection = .connected(via: route)
            startRefreshing()
        } catch {
            client = nil
            connection = .disconnected
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        refreshTask?.cancel()
        refreshTask = nil
        client = nil
        status = nil
        wifi = nil
        connection = .disconnected
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                let mirroring = self.isMirroring
                try? await Task.sleep(for: .milliseconds(mirroring ? 700 : 5000))
                guard !Task.isCancelled else { return }

                if mirroring {
                    await self.captureScreens()
                    tick += 1
                }
                // Status moves slowly; don't refetch it on every mirror frame.
                if !mirroring || tick % 7 == 0 {
                    self.status = try? await self.client?.status()
                }
            }
        }
    }

    private func loadEverything() async throws {
        guard let client else { throw BusyBarError.notConnected }

        // Only the status call decides whether we're connected; the rest just fill the panel,
        // so they overlap. Over BLE the transport serialises them anyway.
        status = try await client.status()
        async let wifi = try? client.wifiStatus()
        async let name = try? client.name()
        async let brightness = try? client.brightness()
        async let volume = try? client.volume()

        self.wifi = await wifi
        self.deviceName = await name ?? ""
        self.brightness = await brightness ?? .auto
        self.volume = await volume ?? 50
    }

    // MARK: - Controls

    private func run(_ work: @escaping (BusyBarClient) async throws -> Void) async {
        guard let client else { return }
        do {
            try await work(client)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func draw(text: String, color: BusyColor, font: BusyFont, screen: Screen) async {
        await run { try await $0.draw(text: text, font: font, color: color, display: screen) }
        await captureScreens()
    }

    func clear() async {
        await run { try await $0.clearDisplay() }
        await captureScreens()
    }

    /// Pulls a frame from both displays. `/screen` is a single capture, not a stream, so
    /// mirroring means asking again on a timer.
    func captureScreens() async {
        guard let client else { return }
        async let front = try? client.screenshot(of: .front)
        async let back = try? client.screenshot(of: .back)
        frontFrame = await front
        backFrame = await back
    }

    func toggleMirroring() {
        isMirroring.toggle()
        startRefreshing()
    }

    func setBrightness(_ value: Brightness) async {
        brightness = value
        await run { try await $0.setBrightness(value) }
    }

    func setVolume(_ value: Double) async {
        volume = value
        await run { try await $0.setVolume(value, silent: true) }
    }

    func press(_ key: InputKey) async {
        await run { try await $0.press(key) }
    }

    func rename(to name: String) async {
        await run { try await $0.setName(name) }
    }
}

extension Optional where Wrapped == String {
    /// The string, unless it's absent or blank.
    var presence: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
