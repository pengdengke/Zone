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
    func testInitWithPersistedSelectedDeviceStartsMonitoringReady() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let persistedSettings = ZoneSettings(
            selectedDevice: SelectedDevice(
                stableID: "token",
                addressString: "AA-BB",
                displayName: "Desk Phone",
                majorDeviceClass: 2
            ),
            lockThreshold: ZoneSettings.default.lockThreshold,
            wakeThreshold: ZoneSettings.default.wakeThreshold,
            signalLossTimeout: ZoneSettings.default.signalLossTimeout,
            slidingWindowSize: ZoneSettings.default.slidingWindowSize,
            launchAtLogin: ZoneSettings.default.launchAtLogin
        )
        try ZoneSettingsStore(defaults: defaults).save(persistedSettings)

        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        XCTAssertEqual(model.settings.selectedDevice?.stableID, "token")
        XCTAssertEqual(model.statusLine, "Monitoring Ready")
    }

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
        let settingsStore = ZoneSettingsStore(defaults: defaults)
        let model = AppModel(
            settingsStore: settingsStore,
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

        let persistedSettings = settingsStore.load()
        XCTAssertEqual(persistedSettings.selectedDevice?.stableID, "token")
        XCTAssertEqual(persistedSettings.selectedDevice?.displayName, "Desk Phone")

        let reloadedModel = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        XCTAssertEqual(reloadedModel.settings.selectedDevice?.stableID, "token")
        XCTAssertEqual(reloadedModel.settings.selectedDevice?.displayName, "Desk Phone")
    }

    func testMissingConfiguredDeviceShowsUnavailableStatus() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = ZoneSettingsStore(defaults: defaults)
        try store.save(
            ZoneSettings(
                selectedDevice: SelectedDevice(
                    stableID: "missing",
                    addressString: "CC-DD",
                    displayName: "Lost Phone",
                    majorDeviceClass: 2
                ),
                lockThreshold: -85,
                wakeThreshold: -55,
                signalLossTimeout: 10,
                slidingWindowSize: 5,
                launchAtLogin: false
            )
        )

        let model = AppModel(
            settingsStore: store,
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()

        XCTAssertEqual(model.statusLine, "Device Unavailable")
    }

    func testClearingSelectedDevicePersistsNilSelection() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settingsStore = ZoneSettingsStore(defaults: defaults)
        let model = AppModel(
            settingsStore: settingsStore,
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
        model.clearSelectedDevice()

        XCTAssertNil(model.settings.selectedDevice)
        XCTAssertEqual(model.statusLine, "Not Configured")

        let persistedSettings = settingsStore.load()
        XCTAssertNil(persistedSettings.selectedDevice)
    }

    func testWeakSamplesTriggerSingleLockAction() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let repository = TestBluetoothRepository(
            connected: [
                BluetoothDeviceSummary(
                    stableID: "token",
                    addressString: "AA-BB",
                    displayName: "Desk Phone",
                    majorDeviceClass: 2
                )
            ],
            readings: [
                "token": [
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -50),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -52),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -51),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -92),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -94),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -96)
                ]
            ]
        )
        let actions = TestSystemActions()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: repository,
            systemActions: actions,
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()
        model.selectConnectedDevice(stableID: "token")
        model.updateSlidingWindowSize(3)

        for offset in 0 ..< 6 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 1)
    }

    func testStrongSamplesWakeAfterLockedState() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let repository = TestBluetoothRepository(
            connected: [
                BluetoothDeviceSummary(
                    stableID: "token",
                    addressString: "AA-BB",
                    displayName: "Desk Phone",
                    majorDeviceClass: 2
                )
            ],
            readings: [
                "token": [
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -50),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -52),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -51),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -92),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -94),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -96),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40)
                ]
            ]
        )
        let actions = TestSystemActions()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: repository,
            systemActions: actions,
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()
        model.selectConnectedDevice(stableID: "token")
        model.updateSlidingWindowSize(3)

        for offset in 0 ..< 9 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 1)
        XCTAssertEqual(actions.wakeCalls, 1)
    }
}
