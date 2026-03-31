import XCTest
@testable import Zone
import ZoneCore

final class TestBluetoothRepository: BluetoothRepository {
    private let connectedDevicesValue: [BluetoothDeviceSummary]
    private let readings: [String: [BluetoothDeviceReading]]
    private var indices: [String: Int] = [:]

    init(
        connected: [BluetoothDeviceSummary],
        readings: [String: [BluetoothDeviceReading]] = [:]
    ) {
        self.connectedDevicesValue = connected
        self.readings = readings
    }

    func connectedDevices() -> [BluetoothDeviceSummary] {
        connectedDevicesValue
    }

    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? {
        guard let values = readings[device.stableID], values.isEmpty == false else {
            return connectedDevicesValue.contains(where: { $0.stableID == device.stableID })
                ? BluetoothDeviceReading(isConnected: true, rawRSSI: -60)
                : nil
        }

        let index = min(indices[device.stableID, default: 0], values.count - 1)
        indices[device.stableID] = index + 1
        return values[index]
    }

    var bluetoothPermissionStatusText: String { "Allowed" }
}

final class TestSystemActions: SystemActionPerforming {
    private(set) var lockCalls = 0
    private(set) var wakeCalls = 0

    func lockScreen() throws {
        lockCalls += 1
    }

    func wakeDisplay() throws {
        wakeCalls += 1
    }
}

final class TestLoginItemController: LoginItemControlling {
    private(set) var lastEnabledValue: Bool?

    func setEnabled(_ enabled: Bool) throws {
        lastEnabledValue = enabled
    }

    var statusText: String { "Enabled" }
}

struct TestAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool { true }
    func promptIfNeeded() {}
}

@MainActor
final class AppModelTests: XCTestCase {
    func testRefreshLoadsConnectedDevicesFromRepository() async throws {
        let repository = TestBluetoothRepository(
            connected: [
                BluetoothDeviceSummary(
                    stableID: "token",
                    addressString: "AA-BB",
                    displayName: "Desk Phone",
                    majorDeviceClass: 2
                )
            ]
        )
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            bluetoothRepository: repository,
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()

        XCTAssertEqual(model.connectedDevices.count, 1)
        XCTAssertEqual(model.connectedDevices.first?.displayName, "Desk Phone")
    }

    func testSelectingADevicePersistsItIntoSettings() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(
                connected: [
                    BluetoothDeviceSummary(
                        stableID: "token",
                        addressString: "AA-BB",
                        displayName: "Desk Phone",
                        majorDeviceClass: 2
                    )
                ]
            ),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()
        model.selectConnectedDevice(stableID: "token")

        XCTAssertEqual(model.settings.selectedDevice?.displayName, "Desk Phone")
    }
}
