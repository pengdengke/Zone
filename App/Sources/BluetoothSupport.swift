import CoreBluetooth
import Foundation
import IOBluetooth
import ZoneCore

enum BluetoothAuthorizationStatus: Equatable {
    case allowed
    case denied
    case restricted
    case notDetermined
    case unknown

    var isAllowed: Bool {
        self == .allowed
    }

    var statusText: String {
        switch self {
        case .allowed:
            return "Allowed"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        case .unknown:
            return "Unknown"
        }
    }
}

protocol BluetoothPermissionControlling {
    var status: BluetoothAuthorizationStatus { get }
    func prepareForAccess()
}

struct BluetoothDeviceSummary: Identifiable, Equatable {
    var id: String { stableID }

    let stableID: String
    let addressString: String
    let displayName: String
    let majorDeviceClass: UInt32?
}

struct BluetoothDeviceReading: Equatable {
    let isConnected: Bool
    let rawRSSI: Int?
}

protocol BluetoothRepository {
    func connectedDevices() -> [BluetoothDeviceSummary]
    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading?
    var bluetoothPermissionStatusText: String { get }
}

final class LiveBluetoothPermissionController: NSObject, BluetoothPermissionControlling, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?

    var status: BluetoothAuthorizationStatus {
        Self.status(from: CBCentralManager.authorization)
    }

    func prepareForAccess() {
        guard centralManager == nil else { return }
        guard status == .notDetermined else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    private static func status(from authorization: CBManagerAuthorization) -> BluetoothAuthorizationStatus {
        switch authorization {
        case .allowedAlways:
            return .allowed
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
}

final class MacBluetoothRepository: BluetoothRepository {
    private let permissionController: BluetoothPermissionControlling

    init(permissionController: BluetoothPermissionControlling = LiveBluetoothPermissionController()) {
        self.permissionController = permissionController
    }

    func connectedDevices() -> [BluetoothDeviceSummary] {
        guard isAccessAllowed else { return [] }

        let sortedDevices = allKnownDevices()
            .filter { $0.isConnected() }
            .map(Self.summary(for:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        var seenStableIDs = Set<String>()
        return sortedDevices.filter { seenStableIDs.insert($0.stableID).inserted }
    }

    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? {
        guard isAccessAllowed else { return nil }
        guard let match = allKnownDevices().first(where: { $0.addressString == device.addressString }) else {
            return nil
        }

        let isConnected = match.isConnected()
        let rawRSSI = isConnected ? Int(match.rawRSSI()) : nil
        let usableRSSI = Self.normalizedRSSI(rawRSSI)

        return BluetoothDeviceReading(
            isConnected: isConnected,
            rawRSSI: usableRSSI
        )
    }

    var bluetoothPermissionStatusText: String {
        permissionController.status.statusText
    }

    private func allKnownDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    }

    private var isAccessAllowed: Bool {
        permissionController.prepareForAccess()
        return permissionController.status.isAllowed
    }

    private static func normalizedRSSI(_ rawRSSI: Int?) -> Int? {
        guard let rawRSSI else { return nil }
        guard rawRSSI < 0, rawRSSI != 127 else { return nil }
        return rawRSSI
    }

    private static func summary(for device: IOBluetoothDevice) -> BluetoothDeviceSummary {
        BluetoothDeviceSummary(
            stableID: device.addressString,
            addressString: device.addressString,
            displayName: device.nameOrAddress,
            majorDeviceClass: device.deviceClassMajor
        )
    }
}

struct PreviewBluetoothRepository: BluetoothRepository {
    func connectedDevices() -> [BluetoothDeviceSummary] { [] }
    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? { nil }
    var bluetoothPermissionStatusText: String { "Unknown" }
}
