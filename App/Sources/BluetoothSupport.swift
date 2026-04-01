import CoreBluetooth
import Foundation
import IOBluetooth
import ZoneCore

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

final class MacBluetoothRepository: BluetoothRepository {
    func connectedDevices() -> [BluetoothDeviceSummary] {
        allKnownDevices()
            .filter { $0.isConnected() }
            .map(Self.summary(for:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? {
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
        switch CBCentralManager.authorization {
        case .allowedAlways:
            return "Allowed"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func allKnownDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
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
