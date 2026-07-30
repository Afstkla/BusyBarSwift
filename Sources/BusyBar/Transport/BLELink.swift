#if canImport(CoreBluetooth)
import CoreBluetooth
import Foundation

/// Owns the CoreBluetooth objects and turns their delegate callbacks into async calls.
///
/// Every mutable property is touched only on `queue`, which is what makes the
/// `@unchecked Sendable` conformance sound.
final class BLELink: NSObject, @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.busy.ble-link")
    private let responseTimeout: TimeInterval

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var tx: CBCharacteristic?
    private var session: CBCharacteristic?

    private var powerOnWaiters: [CheckedContinuation<Void, Error>] = []
    private var connectWaiter: CheckedContinuation<Void, Error>?
    private var discovered: [(peripheral: CBPeripheral, name: String, rssi: Int)] = []
    private var seen: Set<UUID> = []
    private var scanWaiter: CheckedContinuation<[DiscoveredBar], Error>?

    private var exchange: Exchange?

    private struct Exchange {
        var buffer = Data()
        let isComplete: @Sendable (Data) throws -> Bool
        let continuation: CheckedContinuation<Void, Error>
        let timeoutItem: DispatchWorkItem
    }

    init(responseTimeout: TimeInterval) {
        self.responseTimeout = responseTimeout
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
    }

    // MARK: - Connecting

    func scan(duration: TimeInterval) async throws -> [DiscoveredBar] {
        try await waitForPowerOn()
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.discovered = []
                self.seen = []
                self.scanWaiter = continuation
                self.central.scanForPeripherals(withServices: [BLEIdentifiers.advertisedService])
                self.queue.asyncAfter(deadline: .now() + duration) {
                    self.central.stopScan()
                    guard let waiter = self.scanWaiter else { return }
                    self.scanWaiter = nil
                    waiter.resume(returning: self.discovered.map {
                        DiscoveredBar(id: $0.peripheral.identifier, name: $0.name, rssi: $0.rssi)
                    })
                }
            }
        }
    }

    /// Idempotent: returns immediately when the UART characteristics are already live.
    func connect(to id: UUID?, scanDuration: TimeInterval) async throws {
        if await isReady() { return }
        try await waitForPowerOn()

        // A known peripheral can be fetched straight from CoreBluetooth's cache, which skips
        // the whole scan window.
        if let id, let known = await retrieve(id) {
            try await openUART(with: known)
            return
        }

        _ = try await scan(duration: scanDuration)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let match =
                    id.flatMap { wanted in self.discovered.first { $0.peripheral.identifier == wanted } }
                    ?? self.discovered.max { $0.rssi < $1.rssi }

                guard let match else {
                    continuation.resume(throwing: BusyBarError.deviceNotFound)
                    return
                }
                self.beginConnecting(to: match.peripheral, waiter: continuation)
            }
        }
    }

    func disconnect() {
        queue.async {
            if let peripheral = self.peripheral {
                self.central.cancelPeripheralConnection(peripheral)
            }
            self.peripheral = nil
            self.rx = nil
            self.tx = nil
            self.session = nil
        }
    }

    private func isReady() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(
                    returning: self.peripheral?.state == .connected && self.rx != nil && self.tx != nil
                )
            }
        }
    }

    private func retrieve(_ id: UUID) async -> CBPeripheral? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(
                    returning: self.central.retrievePeripherals(withIdentifiers: [id]).first
                )
            }
        }
    }

    private func openUART(with peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { self.beginConnecting(to: peripheral, waiter: continuation) }
        }
    }

    private func beginConnecting(
        to peripheral: CBPeripheral,
        waiter: CheckedContinuation<Void, Error>
    ) {
        connectWaiter = waiter
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    private func waitForPowerOn() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                switch Self.outcome(for: self.central.state) {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                case nil:
                    self.powerOnWaiters.append(continuation)
                }
            }
        }
    }

    /// `nil` while the radio is still settling and the state says nothing yet.
    private static func outcome(for state: CBManagerState) -> Result<Void, Error>? {
        switch state {
        case .poweredOn:
            .success(())
        case .unsupported:
            .failure(BusyBarError.bluetoothUnavailable("this machine has no BLE radio"))
        case .unauthorized:
            .failure(BusyBarError.bluetoothUnavailable("the app is not authorized to use Bluetooth"))
        case .poweredOff:
            .failure(BusyBarError.bluetoothUnavailable("Bluetooth is switched off"))
        default:
            nil
        }
    }

    // MARK: - Request/response

    /// Writes `payload` to RX in MTU-sized pieces, then collects TX indications until
    /// `isComplete` accepts the accumulated buffer.
    func exchange(_ payload: Data, isComplete: @escaping @Sendable (Data) throws -> Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard let peripheral = self.peripheral, let rx = self.rx, peripheral.state == .connected else {
                    continuation.resume(throwing: BusyBarError.notConnected)
                    return
                }
                guard self.exchange == nil else {
                    continuation.resume(throwing: BusyBarError.requestInFlight)
                    return
                }

                let timeoutItem = DispatchWorkItem { [weak self] in
                    guard let self, self.exchange != nil else { return }
                    // The repeater keeps one loopback connection; a half-written request would
                    // poison every later one, so clear it before giving up.
                    self.resetSession()
                    self.finishExchange(with: .failure(BusyBarError.timedOut))
                }
                self.exchange = Exchange(
                    isComplete: isComplete,
                    continuation: continuation,
                    timeoutItem: timeoutItem
                )
                self.queue.asyncAfter(deadline: .now() + self.responseTimeout, execute: timeoutItem)

                let limit = peripheral.maximumWriteValueLength(for: .withResponse)
                for chunk in payload.chunks(of: limit) {
                    peripheral.writeValue(chunk, for: rx, type: .withResponse)
                }
            }
        }
    }

    /// Writing zero to the session characteristic makes the firmware drop and reopen its
    /// loopback connection, clearing any half-finished request.
    private func resetSession() {
        guard let peripheral, let session else { return }
        withUnsafeBytes(of: UInt32(0).littleEndian) {
            peripheral.writeValue(Data($0), for: session, type: .withResponse)
        }
    }

    private func finishExchange(with result: Result<Void, Error>) {
        guard let pending = exchange else { return }
        exchange = nil
        pending.timeoutItem.cancel()
        pending.continuation.resume(with: result)
    }

    private func finishConnecting(with result: Result<Void, Error>) {
        guard let waiter = connectWaiter else { return }
        connectWaiter = nil
        waiter.resume(with: result)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLELink: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let outcome = Self.outcome(for: central.state) else { return }
        let waiters = powerOnWaiters
        powerOnWaiters = []
        for waiter in waiters {
            waiter.resume(with: outcome)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard seen.insert(peripheral.identifier).inserted else { return }
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "BUSY Bar"
        discovered.append((peripheral: peripheral, name: name, rssi: RSSI.intValue))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BLEIdentifiers.uartService])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        finishConnecting(with: .failure(error ?? BusyBarError.notConnected))
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        rx = nil
        tx = nil
        session = nil
        finishExchange(with: .failure(error ?? BusyBarError.notConnected))
        finishConnecting(with: .failure(error ?? BusyBarError.notConnected))
    }
}

// MARK: - CBPeripheralDelegate

extension BLELink: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finishConnecting(with: .failure(error))
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEIdentifiers.uartService }) else {
            finishConnecting(with: .failure(BusyBarError.bluetoothUnavailable(
                "the bar is not exposing its UART service — is BLE enabled on the device?"
            )))
            return
        }
        peripheral.discoverCharacteristics(
            [
                BLEIdentifiers.rxCharacteristic,
                BLEIdentifiers.txCharacteristic,
                BLEIdentifiers.sessionCharacteristic,
            ],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            finishConnecting(with: .failure(error))
            return
        }

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case BLEIdentifiers.rxCharacteristic: rx = characteristic
            case BLEIdentifiers.txCharacteristic: tx = characteristic
            case BLEIdentifiers.sessionCharacteristic: session = characteristic
            default: break
            }
        }

        guard let tx, rx != nil else {
            finishConnecting(with: .failure(BusyBarError.bluetoothUnavailable(
                "the UART service is missing its characteristics"
            )))
            return
        }
        peripheral.setNotifyValue(true, for: tx)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEIdentifiers.txCharacteristic else { return }
        finishConnecting(with: error.map { .failure($0) } ?? .success(()))
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEIdentifiers.rxCharacteristic, let error else { return }
        finishExchange(with: .failure(error))
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == BLEIdentifiers.txCharacteristic else { return }
        if let error {
            finishExchange(with: .failure(error))
            return
        }
        guard var pending = exchange, let value = characteristic.value else { return }

        pending.buffer.append(value)
        exchange = pending
        do {
            if try pending.isComplete(pending.buffer) {
                finishExchange(with: .success(()))
            }
        } catch {
            finishExchange(with: .failure(error))
        }
    }
}

public struct DiscoveredBar: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let rssi: Int
}
#endif
