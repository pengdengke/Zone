import XCTest
@testable import Zone
import ZoneCore

enum TestReleaseCheckerError: Error {
    case offline
}

final class TestReleaseChecker: ReleaseChecking {
    private var results: [Result<GitHubRelease, Error>]
    private(set) var fetchCalls = 0

    init(results: [Result<GitHubRelease, Error>]) {
        self.results = results
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        fetchCalls += 1

        if results.isEmpty {
            throw TestReleaseCheckerError.offline
        }

        return try results.removeFirst().get()
    }
}

struct TestAppVersionProvider: AppVersionProviding {
    let version: AppVersionInfo

    func currentVersion() -> AppVersionInfo {
        version
    }
}

final class TestReleasePageOpener: ReleasePageOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}

final class TestBluetoothRepository: BluetoothRepository {
    private let connectedDevicesValue: [BluetoothDeviceSummary]
    private let readings: [String: [BluetoothDeviceReading]]
    private let bluetoothPermissionStatusValue: String
    private var indices: [String: Int] = [:]

    init(
        connected: [BluetoothDeviceSummary],
        readings: [String: [BluetoothDeviceReading]] = [:],
        bluetoothPermissionStatus: String = "Allowed"
    ) {
        self.connectedDevicesValue = connected
        self.readings = readings
        self.bluetoothPermissionStatusValue = bluetoothPermissionStatus
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

    var bluetoothPermissionStatusText: String { bluetoothPermissionStatusValue }
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

enum TestLoginItemControllerError: Error, CustomStringConvertible {
    case approvalRequired

    var description: String { "approval required" }
}

final class ThrowingLoginItemController: LoginItemControlling {
    private(set) var lastEnabledValue: Bool?

    func setEnabled(_ enabled: Bool) throws {
        lastEnabledValue = enabled
        throw TestLoginItemControllerError.approvalRequired
    }

    var statusText: String { "Requires Approval" }
}

enum TestSettingsStoreError: Error, CustomStringConvertible {
    case saveFailed

    var description: String { "save failed" }
}

final class ThrowingSettingsStore: ZoneSettingsStoring {
    private(set) var currentSettings: ZoneSettings
    private let saveError: Error?

    init(
        initialSettings: ZoneSettings = .default,
        saveError: Error? = nil
    ) {
        currentSettings = initialSettings
        self.saveError = saveError
    }

    func load() -> ZoneSettings {
        currentSettings
    }

    func save(_ settings: ZoneSettings) throws {
        if let saveError {
            throw saveError
        }

        currentSettings = settings
    }
}

struct TestAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool { true }
    func promptIfNeeded() {}
}

@MainActor
final class PromptingAccessibilityPermission: AccessibilityPermissionProviding {
    private(set) var promptCalls = 0

    var isTrusted: Bool { false }

    func promptIfNeeded() {
        promptCalls += 1
    }
}

final class SequenceBluetoothRepository: BluetoothRepository {
    private let connectedDevicesValue: [BluetoothDeviceSummary]
    private let readings: [BluetoothDeviceReading?]
    private var index = 0

    init(
        connected: [BluetoothDeviceSummary],
        readings: [BluetoothDeviceReading?]
    ) {
        self.connectedDevicesValue = connected
        self.readings = readings
    }

    func connectedDevices() -> [BluetoothDeviceSummary] {
        connectedDevicesValue
    }

    func currentReading(for device: SelectedDevice) -> BluetoothDeviceReading? {
        guard connectedDevicesValue.contains(where: { $0.stableID == device.stableID }) else {
            return nil
        }

        let currentIndex = min(index, readings.count - 1)
        index += 1
        return readings[currentIndex]
    }

    var bluetoothPermissionStatusText: String { "Allowed" }
}

final class FailThenSucceedLockSystemActions: SystemActionPerforming {
    private(set) var lockCalls = 0
    private(set) var wakeCalls = 0

    func lockScreen() throws {
        lockCalls += 1
        if lockCalls == 1 {
            throw SystemActionError.accessibilityDenied
        }
    }

    func wakeDisplay() throws {
        wakeCalls += 1
    }
}

final class AlwaysFailingAccessibilityLockSystemActions: SystemActionPerforming {
    private(set) var lockCalls = 0
    private(set) var wakeCalls = 0

    func lockScreen() throws {
        lockCalls += 1
        throw SystemActionError.accessibilityDenied
    }

    func wakeDisplay() throws {
        wakeCalls += 1
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    func testInitAutomaticallyChecksForUpdatesAndShowsAvailableRelease() async throws {
        let releaseChecker = TestReleaseChecker(results: [
            .success(
                GitHubRelease(
                    tagName: "v1.2.3",
                    htmlURL: URL(string: "https://github.com/pengdengke/Zone/releases/tag/v1.2.3")!,
                    publishedAt: Date(timeIntervalSince1970: 1_712_345_678)
                )
            )
        ])
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission(),
            releaseChecker: releaseChecker,
            appVersionProvider: TestAppVersionProvider(
                version: AppVersionInfo(marketingVersion: "1.2.2", buildVersion: "1.2.2")
            ),
            releasePageOpener: TestReleasePageOpener()
        )

        await waitForUpdateCheck(on: model)

        XCTAssertEqual(releaseChecker.fetchCalls, 1)
        XCTAssertEqual(model.currentVersionText, "1.2.2")
        XCTAssertEqual(model.latestReleaseVersionText, "1.2.3")
        XCTAssertEqual(model.updateCheckState, .updateAvailable)
        XCTAssertTrue(model.canOpenLatestReleasePage)
    }

    func testManualCheckFailureShowsFailedState() async throws {
        let releaseChecker = TestReleaseChecker(results: [.failure(TestReleaseCheckerError.offline)])
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission(),
            releaseChecker: releaseChecker,
            appVersionProvider: TestAppVersionProvider(
                version: AppVersionInfo(marketingVersion: "1.2.2", buildVersion: "1.2.2")
            ),
            releasePageOpener: TestReleasePageOpener(),
            autoCheckForUpdates: false
        )

        await model.checkForUpdates()

        XCTAssertEqual(model.updateCheckState, .failed)
        XCTAssertEqual(model.latestReleaseVersionText, model.strings.latestReleaseUnavailableValueText)
        XCTAssertFalse(model.canOpenLatestReleasePage)
    }

    func testManualCheckWithUncomparableReleaseStillShowsReleaseMetadata() async throws {
        let releaseChecker = TestReleaseChecker(results: [
            .success(
                GitHubRelease(
                    tagName: "release-2026-04-02",
                    htmlURL: URL(string: "https://github.com/pengdengke/Zone/releases/tag/release-2026-04-02")!,
                    publishedAt: nil
                )
            )
        ])
        let opener = TestReleasePageOpener()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission(),
            releaseChecker: releaseChecker,
            appVersionProvider: TestAppVersionProvider(
                version: AppVersionInfo(marketingVersion: "1.2.2", buildVersion: "1.2.2")
            ),
            releasePageOpener: opener,
            autoCheckForUpdates: false
        )

        await model.checkForUpdates()
        model.openLatestReleasePage()

        XCTAssertEqual(model.updateCheckState, .comparisonUnavailable)
        XCTAssertEqual(model.latestReleaseVersionText, "release-2026-04-02")
        XCTAssertEqual(opener.openedURLs.count, 1)
    }

    func testInitWithPersistedSelectedDeviceStartsMonitoring() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let persistedSettings = ZoneSettings(
            selectedDevice: SelectedDevice(
                stableID: "token",
                addressString: "AA-BB",
                displayName: "Desk Phone",
                majorDeviceClass: 2
            ),
            language: .english,
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
        XCTAssertEqual(model.statusLine, "Monitoring")
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
        XCTAssertEqual(model.statusLine, "Monitoring")

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
                language: .english,
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

    func testLaunchAtLoginToggleCallsControllerAndPersists() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let loginItem = TestLoginItemController()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: loginItem,
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.setLaunchAtLogin(true)

        XCTAssertTrue(loginItem.lastEnabledValue == true)
        XCTAssertTrue(model.settings.launchAtLogin)
    }

    func testLaunchAtLoginSaveFailureRecordsError() async throws {
        let loginItem = TestLoginItemController()
        let settingsStore = ThrowingSettingsStore(saveError: TestSettingsStoreError.saveFailed)
        let model = AppModel(
            settingsStore: settingsStore,
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: loginItem,
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.setLaunchAtLogin(true)

        XCTAssertNil(loginItem.lastEnabledValue)
        XCTAssertFalse(model.settings.launchAtLogin)
        XCTAssertEqual(model.diagnostics.first, "[ERROR] Login item update failed: save failed")
    }

    func testLaunchAtLoginPersistsPreferenceWhenServiceNeedsApproval() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settingsStore = ZoneSettingsStore(defaults: defaults)
        let loginItem = ThrowingLoginItemController()
        let model = AppModel(
            settingsStore: settingsStore,
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: loginItem,
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.setLaunchAtLogin(true)

        XCTAssertTrue(loginItem.lastEnabledValue == true)
        XCTAssertTrue(model.settings.launchAtLogin)
        XCTAssertTrue(settingsStore.load().launchAtLogin)
        XCTAssertEqual(model.diagnostics.first, "[ERROR] Login item update failed: approval required")
    }

    func testLanguageSelectionPersistsAcrossReloads() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.setLanguage(.simplifiedChinese)

        XCTAssertEqual(model.settings.language, .simplifiedChinese)

        let reloadedModel = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        XCTAssertEqual(reloadedModel.settings.language, .simplifiedChinese)
    }

    func testRefreshConnectedDevicesDeduplicatesDuplicateStableIDs() async throws {
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
                    ),
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

        XCTAssertEqual(model.connectedDevices.count, 1)
        XCTAssertEqual(model.connectedDevices.first?.stableID, "token")
    }

    func testManualLockPromptsAccessibilityOnlyOncePerSession() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let accessibility = PromptingAccessibilityPermission()
        let actions = AlwaysFailingAccessibilityLockSystemActions()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: actions,
            loginItemController: TestLoginItemController(),
            accessibilityPermission: accessibility
        )

        model.lockNow()
        model.lockNow()
        model.lockNow()

        XCTAssertEqual(actions.lockCalls, 3)
        XCTAssertEqual(accessibility.promptCalls, 1)
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

    func testZeroRSSIIsTreatedAsMissingSignal() async throws {
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
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: -40),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: 0),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: 0),
                    BluetoothDeviceReading(isConnected: true, rawRSSI: 0)
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
        model.updateSignalLossTimeout(2)

        for offset in 0 ..< 6 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 1)
        XCTAssertEqual(model.latestRSSIText, "--")
        XCTAssertEqual(model.statusLine, "Locked")
    }

    func testMissingConnectedRSSIRecordsDiagnostic() async throws {
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
                    BluetoothDeviceReading(isConnected: true, rawRSSI: nil)
                ]
            ]
        )
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: repository,
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.refreshConnectedDevices()
        model.selectConnectedDevice(stableID: "token")
        model.poll(at: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(model.latestRSSIText, "--")
        XCTAssertEqual(model.diagnostics.first, "[WARNING] Connected device did not expose a usable RSSI sample.")
    }

    func testUnavailableSelectedDeviceStillLocksAfterSignalLossTimeout() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let device = BluetoothDeviceSummary(
            stableID: "token",
            addressString: "AA-BB",
            displayName: "Desk Phone",
            majorDeviceClass: 2
        )
        let repository = SequenceBluetoothRepository(
            connected: [device],
            readings: [
                BluetoothDeviceReading(isConnected: true, rawRSSI: -57),
                BluetoothDeviceReading(isConnected: true, rawRSSI: -58),
                BluetoothDeviceReading(isConnected: true, rawRSSI: -56),
                nil,
                nil,
                nil
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
        model.updateSignalLossTimeout(2)

        for offset in 0 ..< 6 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 1)
        XCTAssertEqual(model.statusLine, "Locked")
    }

    func testAutomaticLockFailureCanRetryAfterPermissionPrompt() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let device = BluetoothDeviceSummary(
            stableID: "token",
            addressString: "AA-BB",
            displayName: "Desk Phone",
            majorDeviceClass: 2
        )
        let repository = SequenceBluetoothRepository(
            connected: [device],
            readings: [
                BluetoothDeviceReading(isConnected: true, rawRSSI: -57),
                BluetoothDeviceReading(isConnected: true, rawRSSI: -58),
                BluetoothDeviceReading(isConnected: true, rawRSSI: -56),
                nil,
                nil,
                nil,
                nil,
                nil,
                nil
            ]
        )
        let actions = FailThenSucceedLockSystemActions()
        let accessibility = PromptingAccessibilityPermission()
        let model = AppModel(
            settingsStore: ZoneSettingsStore(defaults: defaults),
            bluetoothRepository: repository,
            systemActions: actions,
            loginItemController: TestLoginItemController(),
            accessibilityPermission: accessibility
        )

        model.refreshConnectedDevices()
        model.selectConnectedDevice(stableID: "token")
        model.updateSlidingWindowSize(3)
        model.updateSignalLossTimeout(2)

        for offset in 0 ..< 9 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 2)
        XCTAssertEqual(accessibility.promptCalls, 1)
        XCTAssertEqual(model.statusLine, "Locked")
    }

    func testManualLockLeavesBoundaryEngineReadyForAutomaticWake() async throws {
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

        for offset in 0 ..< 3 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        model.lockNow()
        model.poll(at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(actions.lockCalls, 1)
        XCTAssertEqual(actions.wakeCalls, 1)
        XCTAssertEqual(model.statusLine, "Monitoring")
    }

    func testManualWakeLeavesBoundaryEngineReadyForAutomaticRelock() async throws {
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

        model.wakeDisplayNow()

        for offset in 6 ..< 9 {
            model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
        }

        XCTAssertEqual(actions.lockCalls, 2)
        XCTAssertEqual(actions.wakeCalls, 1)
        XCTAssertEqual(model.statusLine, "Locked")
    }

    func testUpdatingLockThresholdPreservesValidHysteresisWhenPersisted() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settingsStore = ZoneSettingsStore(defaults: defaults)
        let model = AppModel(
            settingsStore: settingsStore,
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.updateLockThreshold(-54)

        XCTAssertEqual(model.settings.lockThreshold, -54)
        XCTAssertEqual(model.settings.wakeThreshold, -53)

        let persistedSettings = settingsStore.load()
        XCTAssertEqual(persistedSettings.lockThreshold, -54)
        XCTAssertEqual(persistedSettings.wakeThreshold, -53)
    }

    func testUpdatingWakeThresholdPreservesValidHysteresisWhenPersisted() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settingsStore = ZoneSettingsStore(defaults: defaults)
        let model = AppModel(
            settingsStore: settingsStore,
            bluetoothRepository: TestBluetoothRepository(connected: []),
            systemActions: TestSystemActions(),
            loginItemController: TestLoginItemController(),
            accessibilityPermission: TestAccessibilityPermission()
        )

        model.updateWakeThreshold(-85)

        XCTAssertEqual(model.settings.wakeThreshold, -85)
        XCTAssertEqual(model.settings.lockThreshold, -86)

        let persistedSettings = settingsStore.load()
        XCTAssertEqual(persistedSettings.wakeThreshold, -85)
        XCTAssertEqual(persistedSettings.lockThreshold, -86)
    }

    private func waitForUpdateCheck(on model: AppModel) async {
        for _ in 0 ..< 100 {
            if model.updateCheckState != .idle, model.updateCheckState != .checking {
                return
            }

            await Task.yield()
        }
    }
}
