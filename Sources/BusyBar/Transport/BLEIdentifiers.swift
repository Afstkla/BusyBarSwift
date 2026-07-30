#if canImport(CoreBluetooth)
import CoreBluetooth

/// UUIDs the firmware exposes, from `applications/services/ble` in busybar-firmware.
///
/// `CBUUID` is immutable once built but predates `Sendable`, hence the unchecked annotations.
public enum BLEIdentifiers {
    /// Advertised 16-bit service class, used to filter scan results.
    public nonisolated(unsafe) static let advertisedService = CBUUID(string: "308A")

    /// Nordic UART Service. `ble_http_repeater` pipes it into the on-device web server.
    public nonisolated(unsafe) static let uartService =
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

    /// Host writes request bytes here.
    public nonisolated(unsafe) static let rxCharacteristic =
        CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    /// Device indicates response bytes back, 237 bytes at a time.
    public nonisolated(unsafe) static let txCharacteristic =
        CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    /// `UInt32` request counter. Writing zero resets the repeater's loopback connection.
    public nonisolated(unsafe) static let sessionCharacteristic =
        CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
}
#endif
