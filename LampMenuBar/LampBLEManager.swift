import Foundation
@preconcurrency import CoreBluetooth
import os

final class LampBLEManager: NSObject, ObservableObject {
    static let shared = LampBLEManager()

    struct BluetoothDebugInfo {
        let state: String
        let authorization: String
        let isScanning: Bool
        let centralIsScanning: Bool
        let discoveryCount: Int
        let lastDiscovery: String
    }

    struct PeripheralInfo: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
        let isConnectable: Bool
    }

    private let targetServiceUUID = CBUUID(string: "FFFF")
    private let targetCharacteristicUUID = CBUUID(string: "FF01")
    private let bleQueue = DispatchQueue(label: "lamp.ble.queue")
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LampShortcuts",
                                category: "BLE")

    private var central: CBCentralManager!
    private var scanContinuation: AsyncStream<PeripheralInfo>.Continuation?
    private var activeScanSession: UUID?
    private var powerContinuation: CheckedContinuation<Void, Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var characteristicContinuation: CheckedContinuation<CBCharacteristic, Error>?
    private var isScanning = false
    private var discoveryCount = 0
    private var lastDiscovery = "None"

    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: bleQueue,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        logger.info("Central created state=\(self.stateLabel(self.central.state)) auth=\(self.authorizationLabel(CBCentralManager.authorization))")
    }

    func startScan() async throws -> AsyncStream<PeripheralInfo> {
        try await ensurePoweredOn()
        guard central.state == .poweredOn else {
            logger.error("startScan blocked state=\(self.stateLabel(self.central.state)) auth=\(self.authorizationLabel(CBCentralManager.authorization))")
            throw LampError.bluetoothUnavailable
        }

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let sessionID = UUID()

            bleQueue.async { [weak self] in
                guard let self else { return }
                activeScanSession = sessionID
                if isScanning {
                    central.stopScan()
                    isScanning = false
                }
                scanContinuation?.finish()
                scanContinuation = continuation
                discoveredPeripherals.removeAll()
                discoveryCount = 0
                lastDiscovery = "None"
                isScanning = true
                logger.info("scanForPeripherals starting state=\(self.stateLabel(self.central.state)) auth=\(self.authorizationLabel(CBCentralManager.authorization))")
                central.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
                logger.info("scanForPeripherals invoked isScanning=\(self.central.isScanning)")
            }

            continuation.onTermination = { [weak self] termination in
                self?.bleQueue.async { [weak self] in
                    guard let self else { return }
                    let isCurrent = self.activeScanSession == sessionID
                    self.logger.info("scanForPeripherals terminated reason=\(self.terminationLabel(termination)) current=\(isCurrent)")
                    guard isCurrent else { return }
                    self.central.stopScan()
                    self.isScanning = false
                    self.scanContinuation = nil
                    self.activeScanSession = nil
                }
            }
        }
    }

    func stopScan() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            activeScanSession = nil
            if isScanning {
                central.stopScan()
                isScanning = false
                logger.info("stopScan invoked")
            }
            scanContinuation?.finish()
            scanContinuation = nil
        }
    }

    func verifyPeripheral(id: UUID) async throws {
        let peripheral = try await retrievePeripheral(id: id)
        _ = try await connectAndDiscover(peripheral: peripheral)
        await performOnQueue {
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    func sendSequence(_ sequence: [Data], to id: UUID) async throws {
        let peripheral = try await retrievePeripheral(id: id)
        let characteristic = try await connectAndDiscover(peripheral: peripheral)
        try await writeSequence(sequence, to: characteristic, peripheral: peripheral)
        await performOnQueue {
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    private func retrievePeripheral(id: UUID) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { continuation in
            bleQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: LampError.deviceNotFound)
                    return
                }
                if let cached = discoveredPeripherals[id] {
                    continuation.resume(returning: cached)
                    return
                }
                let retrieved = central.retrievePeripherals(withIdentifiers: [id])
                if let peripheral = retrieved.first {
                    continuation.resume(returning: peripheral)
                    return
                }
                continuation.resume(throwing: LampError.deviceNotFound)
            }
        }
    }

    private func connectAndDiscover(peripheral: CBPeripheral) async throws -> CBCharacteristic {
        try await ensurePoweredOn()
        await performOnQueue {
            self.central.stopScan()
            self.isScanning = false
            peripheral.delegate = self
        }
        try await withTimeout(12) { [weak self] in
            guard let self else { throw LampError.connectionFailed }
            try await self.connect(peripheral: peripheral)
        }
        let characteristic = try await withTimeout(12) { [weak self] in
            guard let self else { throw LampError.connectionFailed }
            return try await self.discoverCharacteristic(peripheral: peripheral)
        }
        return characteristic
    }

    private func connect(peripheral: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bleQueue.async { [weak self] in
                guard let self else { return }
                connectContinuation?.resume(throwing: LampError.connectionFailed)
                connectContinuation = continuation
                central.connect(peripheral, options: nil)
            }
        }
    }

    private func discoverCharacteristic(peripheral: CBPeripheral) async throws -> CBCharacteristic {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBCharacteristic, Error>) in
            bleQueue.async { [weak self] in
                guard let self else { return }
                characteristicContinuation?.resume(throwing: LampError.characteristicNotFound)
                characteristicContinuation = continuation
                peripheral.discoverServices([targetServiceUUID])
            }
        }
    }

    private func writeSequence(_ sequence: [Data],
                               to characteristic: CBCharacteristic,
                               peripheral: CBPeripheral) async throws {
        let writeType: CBCharacteristicWriteType
        if characteristic.properties.contains(.writeWithoutResponse) {
            writeType = .withoutResponse
        } else if characteristic.properties.contains(.write) {
            writeType = .withResponse
        } else {
            throw LampError.characteristicNotFound
        }

        for _ in 0..<3 {
            for item in sequence {
                await performOnQueue {
                    peripheral.writeValue(item, for: characteristic, type: writeType)
                }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func ensurePoweredOn() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bleQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: LampError.bluetoothUnavailable)
                    return
                }
                switch central.state {
                case .poweredOn:
                    powerContinuation = nil
                    continuation.resume()
                case .unauthorized:
                    powerContinuation = nil
                    continuation.resume(throwing: LampError.bluetoothUnauthorized)
                case .unsupported, .poweredOff:
                    powerContinuation = nil
                    continuation.resume(throwing: LampError.bluetoothUnavailable)
                case .resetting, .unknown:
                    logger.info("ensurePoweredOn waiting state=\(self.stateLabel(self.central.state))")
                    powerContinuation?.resume(throwing: LampError.bluetoothUnavailable)
                    powerContinuation = continuation
                @unknown default:
                    continuation.resume(throwing: LampError.bluetoothUnavailable)
                }
            }
        }
    }

    private func withTimeout<T>(_ seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw LampError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func performOnQueue(_ work: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            bleQueue.async {
                work()
                continuation.resume()
            }
        }
    }

    func debugInfo() -> BluetoothDebugInfo {
        var snapshot: BluetoothDebugInfo?
        bleQueue.sync {
            snapshot = BluetoothDebugInfo(
                state: self.stateLabel(self.central.state),
                authorization: self.authorizationLabel(CBCentralManager.authorization),
                isScanning: isScanning,
                centralIsScanning: central.isScanning,
                discoveryCount: discoveryCount,
                lastDiscovery: lastDiscovery
            )
        }
        return snapshot ?? BluetoothDebugInfo(
            state: self.stateLabel(self.central.state),
            authorization: self.authorizationLabel(CBCentralManager.authorization),
            isScanning: false,
            centralIsScanning: false,
            discoveryCount: 0,
            lastDiscovery: "None"
        )
    }

    private func stateLabel(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered Off"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .resetting: return "Resetting"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private func authorizationLabel(_ authorization: CBManagerAuthorization) -> String {
        switch authorization {
        case .allowedAlways: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private func terminationLabel(_ termination: AsyncStream<PeripheralInfo>.Continuation.Termination) -> String {
        switch termination {
        case .cancelled: return "Cancelled"
        case .finished: return "Finished"
        @unknown default: return "Unknown"
        }
    }
}

extension LampBLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("centralManagerDidUpdateState state=\(self.stateLabel(central.state)) auth=\(self.authorizationLabel(CBCentralManager.authorization))")
        let continuation = powerContinuation
        powerContinuation = nil
        guard let continuation else { return }
        switch central.state {
        case .poweredOn:
            continuation.resume()
        case .unauthorized:
            continuation.resume(throwing: LampError.bluetoothUnauthorized)
        case .unsupported, .poweredOff:
            continuation.resume(throwing: LampError.bluetoothUnavailable)
        case .resetting, .unknown:
            powerContinuation = continuation
        @unknown default:
            continuation.resume(throwing: LampError.bluetoothUnavailable)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "Unknown"
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? false
        let isNew = discoveredPeripherals[peripheral.identifier] == nil
        if isNew {
            discoveredPeripherals[peripheral.identifier] = peripheral
            logger.info("didDiscover name=\(name) id=\(peripheral.identifier.uuidString) rssi=\(RSSI.intValue) connectable=\(isConnectable)")
        }

        let info = PeripheralInfo(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            isConnectable: isConnectable
        )
        discoveryCount += 1
        lastDiscovery = "\(name) | \(peripheral.identifier.uuidString) | RSSI \(RSSI.intValue)"
        scanContinuation?.yield(info)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectContinuation?.resume(throwing: error ?? LampError.connectionFailed)
        connectContinuation = nil
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectContinuation?.resume()
        connectContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            characteristicContinuation?.resume(throwing: error)
            characteristicContinuation = nil
            return
        }

        guard let services = peripheral.services else {
            characteristicContinuation?.resume(throwing: LampError.serviceNotFound)
            characteristicContinuation = nil
            return
        }

        guard let service = services.first(where: { $0.uuid == targetServiceUUID }) else {
            characteristicContinuation?.resume(throwing: LampError.serviceNotFound)
            characteristicContinuation = nil
            return
        }

        peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            characteristicContinuation?.resume(throwing: error)
            characteristicContinuation = nil
            return
        }

        guard let characteristics = service.characteristics else {
            characteristicContinuation?.resume(throwing: LampError.characteristicNotFound)
            characteristicContinuation = nil
            return
        }

        guard let characteristic = characteristics.first(where: { $0.uuid == targetCharacteristicUUID }) else {
            characteristicContinuation?.resume(throwing: LampError.characteristicNotFound)
            characteristicContinuation = nil
            return
        }

        characteristicContinuation?.resume(returning: characteristic)
        characteristicContinuation = nil
    }
}

extension LampBLEManager: @unchecked Sendable {}
extension CBPeripheral: @unchecked Sendable {}
extension CBCharacteristic: @unchecked Sendable {}
