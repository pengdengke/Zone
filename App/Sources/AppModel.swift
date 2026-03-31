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
    private var boundaryEngine: BoundaryEngine
    private var diagnosticsBuffer = DiagnosticsBuffer(capacity: 20)
    private var pollTimer: Timer?

    init(
        settingsStore: ZoneSettingsStore = ZoneSettingsStore(),
        bluetoothRepository: BluetoothRepository = MacBluetoothRepository(),
        systemActions: SystemActionPerforming = LiveSystemActions(),
        loginItemController: LoginItemControlling = PreviewLoginItemController(),
        accessibilityPermission: AccessibilityPermissionProviding = LiveAccessibilityPermission()
    ) {
        self.settingsStore = settingsStore
        self.bluetoothRepository = bluetoothRepository
        self.systemActions = systemActions
        self.loginItemController = loginItemController
        self.accessibilityPermission = accessibilityPermission
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings
        self.boundaryEngine = BoundaryEngine(settings: loadedSettings)
        self.statusLine = loadedSettings.selectedDevice == nil ? "Not Configured" : "Monitoring"
        record(.info, "Zone is ready to be configured.")

        if loadedSettings.selectedDevice != nil {
            startPolling()
        }
    }

    var menuBarSymbol: String {
        switch statusLine {
        case "Locked":
            return "lock.shield.fill"
        case "Paused":
            return "pause.circle"
        case "Device Unavailable":
            return "bolt.horizontal.circle"
        default:
            return settings.selectedDevice == nil ? "dot.scope" : "lock.shield"
        }
    }

    var isMonitoringPaused: Bool {
        statusLine == "Paused"
    }

    func refreshConnectedDevices() {
        connectedDevices = bluetoothRepository.connectedDevices()

        if let selected = settings.selectedDevice,
           bluetoothRepository.currentReading(for: selected) == nil {
            latestRSSIText = "--"
            statusLine = "Device Unavailable"
            record(.warning, "Selected device is no longer known to macOS.")
            return
        }

        guard statusLine != "Paused", statusLine != "Locked" else {
            return
        }

        statusLine = settings.selectedDevice == nil ? "Not Configured" : "Monitoring"
    }

    func selectConnectedDevice(stableID: String) {
        guard let match = connectedDevices.first(where: { $0.stableID == stableID }) else { return }
        settings.selectedDevice = SelectedDevice(
            stableID: match.stableID,
            addressString: match.addressString,
            displayName: match.displayName,
            majorDeviceClass: match.majorDeviceClass
        )
        latestRSSIText = "--"
        boundaryEngine = BoundaryEngine(settings: settings)
        persistSettings()
        statusLine = "Monitoring"
        record(.info, "Selected device: \(match.displayName)")
        startPolling()
    }

    func clearSelectedDevice() {
        pollTimer?.invalidate()
        pollTimer = nil
        settings.selectedDevice = nil
        latestRSSIText = "--"
        boundaryEngine = BoundaryEngine(settings: settings)
        try? settingsStore.save(settings)
        statusLine = "Not Configured"
    }

    func updateLockThreshold(_ value: Int) {
        settings.lockThreshold = value
        persistSettings()
    }

    func updateWakeThreshold(_ value: Int) {
        settings.wakeThreshold = value
        persistSettings()
    }

    func updateSignalLossTimeout(_ value: Double) {
        settings.signalLossTimeout = value
        persistSettings()
    }

    func updateSlidingWindowSize(_ value: Int) {
        settings.slidingWindowSize = value
        persistSettings()
    }

    func pauseMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        statusLine = "Paused"
    }

    func resumeMonitoring() {
        guard settings.selectedDevice != nil else {
            statusLine = "Not Configured"
            return
        }

        startPolling()
        statusLine = monitoringStatus()
    }

    func lockNow() {
        do {
            try systemActions.lockScreen()
            statusLine = "Locked"
            record(.warning, "Manual lock executed.")
        } catch {
            accessibilityPermission.promptIfNeeded()
            record(.error, "Lock failed: \(error)")
        }
    }

    func wakeDisplayNow() {
        do {
            try systemActions.wakeDisplay()
            statusLine = monitoringStatus()
            record(.info, "Manual wake executed.")
        } catch {
            record(.error, "Wake failed: \(error)")
        }
    }

    func poll(at date: Date = Date()) {
        guard let selected = settings.selectedDevice else {
            latestRSSIText = "--"
            statusLine = "Not Configured"
            return
        }

        guard let reading = bluetoothRepository.currentReading(for: selected) else {
            latestRSSIText = "--"
            statusLine = "Device Unavailable"
            record(.warning, "Configured device is unavailable.")
            return
        }

        if reading.isConnected, let rawRSSI = reading.rawRSSI {
            latestRSSIText = "\(rawRSSI) dBm"
            record(.info, "RSSI sample: \(rawRSSI) dBm")
            if let transition = boundaryEngine.ingest(rssi: rawRSSI, at: date) {
                apply(transition)
            } else if boundaryEngine.state != .locked {
                statusLine = monitoringStatus()
            }
            return
        }

        latestRSSIText = "--"
        if let transition = boundaryEngine.noteMissingSignal(at: date) {
            apply(transition)
        } else if boundaryEngine.state != .locked {
            statusLine = monitoringStatus()
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func apply(_ transition: BoundaryTransition) {
        switch transition.action {
        case .lock:
            do {
                try systemActions.lockScreen()
                statusLine = "Locked"
            } catch {
                accessibilityPermission.promptIfNeeded()
                statusLine = monitoringStatus()
                record(.error, "Automatic lock failed: \(error)")
                return
            }
        case .wakeDisplay:
            do {
                try systemActions.wakeDisplay()
                statusLine = monitoringStatus()
            } catch {
                record(.error, "Automatic wake failed: \(error)")
                return
            }
        case .none:
            statusLine = transition.newState == .locked ? "Locked" : monitoringStatus()
        }

        let averageText: String
        if let average = transition.averageRSSI {
            averageText = String(format: "%.1f", average)
            record(.info, "Boundary transition: \(transition.reason) at avg \(averageText) dBm")
        } else {
            record(.info, "Boundary transition: \(transition.reason)")
        }
    }

    private func record(_ level: DiagnosticEntry.Level, _ message: String) {
        if let latestEntry = diagnosticsBuffer.entries.first,
           latestEntry.level == level,
           latestEntry.message == message {
            diagnostics = diagnosticsBuffer.entries.map(Self.formatDiagnostic)
            return
        }

        diagnosticsBuffer.append(level: level, message: message)
        diagnostics = diagnosticsBuffer.entries.map(Self.formatDiagnostic)
    }

    private func persistSettings() {
        boundaryEngine = BoundaryEngine(settings: settings)
        try? settingsStore.save(settings)
    }

    private func monitoringStatus() -> String {
        settings.selectedDevice == nil ? "Not Configured" : "Monitoring"
    }

    private static func formatDiagnostic(_ entry: DiagnosticEntry) -> String {
        "[\(entry.level.rawValue.uppercased())] \(entry.message)"
    }
}
