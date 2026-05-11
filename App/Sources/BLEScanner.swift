import CoreBluetooth
import Foundation

struct BLEReading: Equatable {
    let peripheralID: UUID
    let rssi: Int
    let deviceName: String?
}

protocol BLEScanning: AnyObject {
    var latestReading: BLEReading? { get }
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

    private(set) var latestReading: BLEReading?
    var onReadingUpdated: ((BLEReading) -> Void)?

    init(centralManager: CBCentralManaging? = nil) {
        self.centralManager = centralManager ?? CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
    }

    func startScanning(forDeviceName name: String) {
        targetDeviceName = name
        matchedPeripheralID = nil
        latestReading = nil

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
        latestReading = nil
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
        latestReading = reading
        onReadingUpdated?(reading)
    }
}
