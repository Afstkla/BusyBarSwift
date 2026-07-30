import Foundation

extension BusyBarClient {
    // MARK: - Bluetooth

    public func bleStatus() async throws -> BLEStatus {
        try await decode(BLEStatus.self, "GET", "/ble/status")
    }

    /// Enables the radio and starts advertising.
    ///
    /// This is the call that makes ``BLETransport`` usable, so it has to arrive over
    /// USB or Wi-Fi the first time.
    public func enableBLE() async throws {
        try await perform("POST", "/ble/enable")
    }

    public func disableBLE() async throws {
        try await perform("POST", "/ble/disable")
    }

    /// Forgets the paired device, making the bar discoverable again.
    public func forgetBLEPairing() async throws {
        try await perform("DELETE", "/ble/pairing")
    }

    // MARK: - Wi-Fi

    public func wifiStatus() async throws -> WifiStatus {
        try await decode(WifiStatus.self, "GET", "/wifi/status")
    }

    // MARK: - Account

    public func accountInfo() async throws -> AccountInfo {
        try await decode(AccountInfo.self, "GET", "/account/info")
    }

    /// The bar's MQTT connection state.
    public func accountStatus() async throws -> AccountStatus {
        try await decode(AccountStatus.self, "GET", "/account/status")
    }

    public func accountBackend() async throws -> AccountBackend {
        try await decode(AccountBackend.self, "GET", "/account/backend")
    }

    // MARK: - Smart home

    public func smartHomePairingStatus() async throws -> SmartHomePairingInfo {
        try await decode(SmartHomePairingInfo.self, "GET", "/smart_home/pairing")
    }

    /// Opens a Matter commissioning window and returns the codes to pair with.
    public func startSmartHomePairing() async throws -> SmartHomePairingPayload {
        try await decode(SmartHomePairingPayload.self, "POST", "/smart_home/pairing")
    }

    /// Erases every Matter fabric. The bar needs a restart afterwards.
    public func eraseSmartHomePairings() async throws {
        try await perform("DELETE", "/smart_home/pairing")
    }

    public func smartHomeSwitch() async throws -> SmartHomeSwitchState {
        try await decode(SmartHomeSwitchState.self, "GET", "/smart_home/switch")
    }

    public func setSmartHomeSwitch(_ state: SmartHomeSwitchState) async throws {
        try await send("POST", "/smart_home/switch", json: state)
    }

    public func setSmartHomeSwitch(on: Bool) async throws {
        try await setSmartHomeSwitch(SmartHomeSwitchState(state: on))
    }
}
