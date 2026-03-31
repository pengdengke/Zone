import Combine
import Foundation
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

struct PreviewBluetoothRepository: BluetoothRepository {
    func connectedDevices() -> [BluetoothDeviceSummary] { [] }
    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? { nil }
    var bluetoothPermissionStatusText: String { "Unknown" }
}
