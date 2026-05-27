import CoreBluetooth
import Foundation

struct BLEReading: Equatable {
    let peripheralID: UUID
    let rssi: Int
    let deviceName: String?
}

protocol BLEScanning: AnyObject {
    var latestReading: BLEReading? { get }
    var freshReading: BLEReading? { get }
    func startScanning(forDeviceName name: String)
    func stopScanning()
}

protocol CBCentralManaging: AnyObject {
    var state: CBManagerState { get }
    var delegate: CBCentralManagerDelegate? { get set }
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
}

extension CBCentralManager: CBCentralManaging {}

final class BLEScanner: NSObject, BLEScanning, CBCentralManagerDelegate {
    private let centralManager: CBCentralManaging
    private var targetDeviceName: String?
    private var matchedPeripheralID: UUID?
    private let lock = NSLock()
    private var lastReadingTime: Date?

    private(set) var latestReading: BLEReading?
    var onReadingUpdated: ((BLEReading) -> Void)?

    /// Returns the latest reading only if it's still fresh (within timeout)
    var freshReading: BLEReading? {
        lock.lock()
        defer { lock.unlock() }
        guard let reading = latestReading, let time = lastReadingTime else { return nil }
        guard Date().timeIntervalSince(time) < Self.readingTimeout else {
            return nil
        }
        return reading
    }

    /// Time interval after which a BLE reading is considered stale (seconds)
    static let readingTimeout: TimeInterval = 5

    init(centralManager: CBCentralManaging? = nil) {
        self.centralManager = centralManager ?? CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }

    func startScanning(forDeviceName name: String) {
        targetDeviceName = name
        matchedPeripheralID = nil
        lock.withLock {
            latestReading = nil
            lastReadingTime = nil
        }

        guard centralManager.state == .poweredOn else { return }

        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ]
        centralManager.scanForPeripherals(withServices: nil, options: options)
    }

    func stopScanning() {
        centralManager.stopScan()
        targetDeviceName = nil
        matchedPeripheralID = nil
        lock.withLock {
            latestReading = nil
            lastReadingTime = nil
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn, let targetName = targetDeviceName else { return }

        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ]
        central.scanForPeripherals(withServices: nil, options: options)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue
        guard rssiValue < 0, rssiValue != 127 else { return }

        let peripheralID = peripheral.identifier
        let peripheralName = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)

        if let matchedID = matchedPeripheralID {
            guard peripheralID == matchedID else { return }
        } else {
            guard let peripheralName, let targetName = targetDeviceName else { return }
            guard peripheralName.localizedCaseInsensitiveCompare(targetName) == .orderedSame else { return }
            matchedPeripheralID = peripheralID
        }

        let reading = BLEReading(
            peripheralID: peripheralID,
            rssi: rssiValue,
            deviceName: peripheralName
        )
        lock.withLock {
            latestReading = reading
            lastReadingTime = Date()
        }
        onReadingUpdated?(reading)
    }
}
