import Combine
import Foundation
import ZoneCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ZoneSettings
    @Published var connectedDevices: [BluetoothDeviceSummary] = []
    @Published var statusLine = "Not Configured"
    @Published var latestRSSIText = "--"
    @Published var diagnostics: [String] = ["Zone is ready to be configured."]

    private let settingsStore: ZoneSettingsStore
    private let bluetoothRepository: BluetoothRepository
    private let systemActions: SystemActionPerforming
    private let loginItemController: LoginItemControlling
    private let accessibilityPermission: AccessibilityPermissionProviding

    init(
        settingsStore: ZoneSettingsStore = ZoneSettingsStore(),
        bluetoothRepository: BluetoothRepository = MacBluetoothRepository(),
        systemActions: SystemActionPerforming = PreviewSystemActions(),
        loginItemController: LoginItemControlling = PreviewLoginItemController(),
        accessibilityPermission: AccessibilityPermissionProviding = PreviewAccessibilityPermission()
    ) {
        self.settingsStore = settingsStore
        self.bluetoothRepository = bluetoothRepository
        self.systemActions = systemActions
        self.loginItemController = loginItemController
        self.accessibilityPermission = accessibilityPermission
        self.settings = settingsStore.load()
        self.statusLine = self.settings.selectedDevice == nil ? "Not Configured" : "Monitoring Ready"
    }

    var menuBarSymbol: String {
        settings.selectedDevice == nil ? "dot.scope" : "lock.shield"
    }

    func refreshConnectedDevices() {
        connectedDevices = bluetoothRepository.connectedDevices()

        if let selected = settings.selectedDevice,
           bluetoothRepository.currentReading(for: selected) == nil {
            statusLine = "Device Unavailable"
            diagnostics.insert("Selected device is no longer known to macOS.", at: 0)
            return
        }

        statusLine = settings.selectedDevice == nil ? "Not Configured" : "Monitoring Ready"
    }

    func selectConnectedDevice(stableID: String) {
        guard let match = connectedDevices.first(where: { $0.stableID == stableID }) else { return }
        settings.selectedDevice = SelectedDevice(
            stableID: match.stableID,
            addressString: match.addressString,
            displayName: match.displayName,
            majorDeviceClass: match.majorDeviceClass
        )
        try? settingsStore.save(settings)
        statusLine = "Monitoring Ready"
        diagnostics.insert("Selected device: \(match.displayName)", at: 0)
    }

    func clearSelectedDevice() {
        settings.selectedDevice = nil
        try? settingsStore.save(settings)
        statusLine = "Not Configured"
    }

    func pauseMonitoring() {
        statusLine = "Paused"
    }

    func resumeMonitoring() {
        statusLine = settings.selectedDevice == nil ? "Not Configured" : "Monitoring Ready"
    }

    func lockNow() {
        try? systemActions.lockScreen()
    }

    func wakeDisplayNow() {
        try? systemActions.wakeDisplay()
    }
}
