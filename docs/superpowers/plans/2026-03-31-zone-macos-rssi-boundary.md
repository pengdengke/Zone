# Zone macOS RSSI Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that monitors a selected connected Bluetooth device's RSSI, locks the Mac when signal weakens or disappears, and wakes the display back to the login screen when the device returns.

**Architecture:** Keep the threshold logic, settings model, persistence, and diagnostics in a Swift Package called `ZoneCore` so they can be exercised with `swift test`. Use `xcodegen` to define a native SwiftUI macOS application that depends on `ZoneCore` and owns menu bar UI, IOBluetooth integration, lock and wake actions, login-item wiring, and DMG packaging.

**Tech Stack:** Swift 6, SwiftUI, AppKit, IOBluetooth, CoreBluetooth authorization APIs, IOKit Power Management, ServiceManagement, XCTest, XcodeGen

---

## File Structure

- Create: `.gitignore`
- Create: `Package.swift`
- Create: `project.yml`
- Create: `Sources/ZoneCore/ZoneSettings.swift`
- Create: `Sources/ZoneCore/BoundaryEngine.swift`
- Create: `Sources/ZoneCore/DiagnosticsBuffer.swift`
- Create: `Sources/ZoneCore/ZoneSettingsStore.swift`
- Create: `Tests/ZoneCoreTests/ZoneSettingsTests.swift`
- Create: `Tests/ZoneCoreTests/BoundaryEngineTests.swift`
- Create: `Tests/ZoneCoreTests/ZoneSettingsStoreTests.swift`
- Create: `Tests/ZoneCoreTests/DiagnosticsBufferTests.swift`
- Create: `App/Sources/ZoneApp.swift`
- Create: `App/Sources/AppModel.swift`
- Create: `App/Sources/StatusMenuContent.swift`
- Create: `App/Sources/SettingsView.swift`
- Create: `App/Sources/DiagnosticsView.swift`
- Create: `App/Sources/BluetoothSupport.swift`
- Create: `App/Sources/SystemServices.swift`
- Create: `App/Tests/AppModelTests.swift`
- Create: `App/Resources/Assets.xcassets/Contents.json`
- Create: `scripts/generate_app_icon.swift`
- Create: `scripts/build_dmg.sh`

### Task 1: Prepare Native Toolchain

**Files:**
- Create: none

- [ ] **Step 1: Verify a full Xcode app bundle exists**

Run:

```bash
ls /Applications/Xcode.app
```

Expected: the command prints `/Applications/Xcode.app`

- [ ] **Step 2: Point `xcode-select` at full Xcode instead of Command Line Tools**

Run:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Expected: no output

- [ ] **Step 3: Verify `xcodebuild` is usable**

Run:

```bash
xcodebuild -version
```

Expected: output starts with `Xcode`

- [ ] **Step 4: Verify `xcodegen` is available**

Run:

```bash
xcodegen version
```

Expected: output includes `Version:`

### Task 2: Bootstrap The Repo, Core Settings Model, And Menu Bar Shell

**Files:**
- Create: `.gitignore`
- Create: `Package.swift`
- Create: `project.yml`
- Create: `Sources/ZoneCore/ZoneSettings.swift`
- Create: `Tests/ZoneCoreTests/ZoneSettingsTests.swift`
- Create: `App/Sources/ZoneApp.swift`
- Create: `App/Sources/AppModel.swift`
- Create: `App/Sources/StatusMenuContent.swift`
- Create: `App/Sources/SettingsView.swift`
- Create: `App/Sources/DiagnosticsView.swift`

- [ ] **Step 1: Write the failing settings tests**

```swift
import XCTest
@testable import ZoneCore

final class ZoneSettingsTests: XCTestCase {
    func testDefaultSettingsMatchApprovedSpec() {
        let settings = ZoneSettings.default

        XCTAssertNil(settings.selectedDevice)
        XCTAssertEqual(settings.lockThreshold, -85)
        XCTAssertEqual(settings.wakeThreshold, -55)
        XCTAssertEqual(settings.signalLossTimeout, 10)
        XCTAssertEqual(settings.slidingWindowSize, 5)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testSelectedDeviceRoundTripsThroughCodable() throws {
        let settings = ZoneSettings(
            selectedDevice: SelectedDevice(
                stableID: "AA-BB-CC",
                addressString: "AA-BB-CC",
                displayName: "My Phone",
                majorDeviceClass: 2
            ),
            lockThreshold: -80,
            wakeThreshold: -50,
            signalLossTimeout: 12,
            slidingWindowSize: 7,
            launchAtLogin: true
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ZoneSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }
}
```

- [ ] **Step 2: Run the settings tests and confirm they fail before implementation**

Run:

```bash
swift test --filter ZoneSettingsTests
```

Expected: FAIL with missing `ZoneCore` sources or missing `ZoneSettings` symbols

- [ ] **Step 3: Add the package manifest, XcodeGen manifest, settings model, and minimal app shell**

`.gitignore`

```gitignore
.DS_Store
.build
build
DerivedData
Zone.xcodeproj
*.xcarchive
*.dmg
xcuserdata
```

`Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZoneCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ZoneCore", targets: ["ZoneCore"])
    ],
    targets: [
        .target(
            name: "ZoneCore",
            path: "Sources/ZoneCore"
        ),
        .testTarget(
            name: "ZoneCoreTests",
            dependencies: ["ZoneCore"],
            path: "Tests/ZoneCoreTests"
        )
    ]
)
```

`project.yml`

```yaml
name: Zone
options:
  bundleIdPrefix: com.pengdengke
configs:
  Debug: debug
  Release: release
packages:
  ZoneCore:
    path: .
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  Zone:
    type: application
    platform: macOS
    sources:
      - App/Sources
    info:
      properties:
        CFBundleDisplayName: Zone
        LSUIElement: true
        NSBluetoothAlwaysUsageDescription: Zone reads Bluetooth signal strength from your selected device to decide when to lock or wake your Mac.
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.pengdengke.Zone
        PRODUCT_NAME: Zone
        SWIFT_VERSION: "6.0"
    dependencies:
      - package: ZoneCore
        product: ZoneCore
schemes:
  Zone:
    build:
      targets:
        Zone: all
```

`Sources/ZoneCore/ZoneSettings.swift`

```swift
import Foundation

public struct SelectedDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: String { stableID }

    public let stableID: String
    public let addressString: String
    public let displayName: String
    public let majorDeviceClass: UInt32?

    public init(
        stableID: String,
        addressString: String,
        displayName: String,
        majorDeviceClass: UInt32?
    ) {
        self.stableID = stableID
        self.addressString = addressString
        self.displayName = displayName
        self.majorDeviceClass = majorDeviceClass
    }
}

public struct ZoneSettings: Codable, Equatable, Sendable {
    public var selectedDevice: SelectedDevice?
    public var lockThreshold: Int
    public var wakeThreshold: Int
    public var signalLossTimeout: TimeInterval
    public var slidingWindowSize: Int
    public var launchAtLogin: Bool

    public init(
        selectedDevice: SelectedDevice?,
        lockThreshold: Int,
        wakeThreshold: Int,
        signalLossTimeout: TimeInterval,
        slidingWindowSize: Int,
        launchAtLogin: Bool
    ) {
        self.selectedDevice = selectedDevice
        self.lockThreshold = lockThreshold
        self.wakeThreshold = wakeThreshold
        self.signalLossTimeout = signalLossTimeout
        self.slidingWindowSize = slidingWindowSize
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = ZoneSettings(
        selectedDevice: nil,
        lockThreshold: -85,
        wakeThreshold: -55,
        signalLossTimeout: 10,
        slidingWindowSize: 5,
        launchAtLogin: false
    )
}
```

`App/Sources/AppModel.swift`

```swift
import Combine
import Foundation
import ZoneCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ZoneSettings = .default
    @Published var connectedDevices: [SelectedDevice] = []
    @Published var statusLine = "Not Configured"
    @Published var latestRSSIText = "--"
    @Published var diagnostics: [String] = ["Zone is ready to be configured."]

    var menuBarSymbol: String {
        settings.selectedDevice == nil ? "dot.scope" : "lock.shield"
    }

    func pauseMonitoring() {}
    func resumeMonitoring() {}
    func lockNow() {}
    func wakeDisplayNow() {}
}
```

`App/Sources/ZoneApp.swift`

```swift
import AppKit
import SwiftUI

@main
struct ZoneApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Zone", systemImage: model.menuBarSymbol) {
            StatusMenuContent(model: model)
        }

        Window("Zone Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 480, minHeight: 560)
        }
    }
}
```

`App/Sources/StatusMenuContent.swift`

```swift
import SwiftUI

struct StatusMenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusLine)
                .font(.headline)

            Text("RSSI: \(model.latestRSSIText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Settings") {
                openWindow(id: "settings")
            }

            Button("Pause Monitoring") {
                model.pauseMonitoring()
            }

            Button("Resume Monitoring") {
                model.resumeMonitoring()
            }

            Button("Lock Now") {
                model.lockNow()
            }

            Button("Wake Display Now") {
                model.wakeDisplayNow()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
```

`App/Sources/DiagnosticsView.swift`

```swift
import SwiftUI

struct DiagnosticsView: View {
    let messages: [String]

    var body: some View {
        List(messages, id: \.self) { message in
            Text(message)
                .font(.system(.body, design: .monospaced))
        }
        .frame(minHeight: 180)
    }
}
```

`App/Sources/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                if model.connectedDevices.isEmpty {
                    Text("No connected Bluetooth device selected yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName)
                    }
                }
            }

            Section("Thresholds") {
                Text("Lock below: \(model.settings.lockThreshold) dBm")
                Text("Wake above: \(model.settings.wakeThreshold) dBm")
                Text("Signal loss timeout: \(Int(model.settings.signalLossTimeout)) s")
                Text("Sliding window: \(model.settings.slidingWindowSize)")
            }

            Section("Diagnostics") {
                DiagnosticsView(messages: model.diagnostics)
            }
        }
        .padding(16)
    }
}
```

- [ ] **Step 4: Run tests and verify the settings model passes**

Run:

```bash
swift test --filter ZoneSettingsTests
```

Expected: PASS

- [ ] **Step 5: Generate the Xcode project and build the shell app**

Run:

```bash
xcodegen generate
xcodebuild -project Zone.xcodeproj -scheme Zone -configuration Debug -destination 'platform=macOS' build
```

Expected: `xcodegen` prints `Generated project at .../Zone.xcodeproj` and `xcodebuild` ends with `BUILD SUCCEEDED`

- [ ] **Step 6: Commit the bootstrap**

Run:

```bash
git add .gitignore Package.swift project.yml Sources/ZoneCore/ZoneSettings.swift Tests/ZoneCoreTests/ZoneSettingsTests.swift App/Sources/ZoneApp.swift App/Sources/AppModel.swift App/Sources/StatusMenuContent.swift App/Sources/SettingsView.swift App/Sources/DiagnosticsView.swift
git commit -m "chore: bootstrap Zone app shell and settings model"
```

### Task 3: Implement The Boundary Engine With TDD

**Files:**
- Create: `Sources/ZoneCore/BoundaryEngine.swift`
- Create: `Tests/ZoneCoreTests/BoundaryEngineTests.swift`

- [ ] **Step 1: Write the failing boundary-engine tests**

```swift
import XCTest
@testable import ZoneCore

final class BoundaryEngineTests: XCTestCase {
    func testThreeSamplesExitUnknownWithoutLocking() {
        var engine = BoundaryEngine(settings: .default)
        let base = Date(timeIntervalSince1970: 1_000)

        XCTAssertNil(engine.ingest(rssi: -60, at: base))
        XCTAssertNil(engine.ingest(rssi: -62, at: base.addingTimeInterval(1)))

        let transition = engine.ingest(rssi: -61, at: base.addingTimeInterval(2))

        XCTAssertEqual(transition?.newState, .unlocked)
        XCTAssertNil(transition?.action)
    }

    func testWeakAverageLocksExactlyOnce() {
        var engine = BoundaryEngine(settings: .default)
        let base = Date(timeIntervalSince1970: 2_000)

        _ = engine.ingest(rssi: -50, at: base)
        _ = engine.ingest(rssi: -52, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -51, at: base.addingTimeInterval(2))
        _ = engine.ingest(rssi: -92, at: base.addingTimeInterval(3))
        _ = engine.ingest(rssi: -94, at: base.addingTimeInterval(4))

        let firstLock = engine.ingest(rssi: -96, at: base.addingTimeInterval(5))
        let secondLock = engine.ingest(rssi: -97, at: base.addingTimeInterval(6))

        XCTAssertEqual(firstLock?.action, .lock)
        XCTAssertNil(secondLock)
    }

    func testSignalLossLocksAfterConfiguredTimeout() {
        var engine = BoundaryEngine(settings: .default)
        let base = Date(timeIntervalSince1970: 3_000)

        _ = engine.ingest(rssi: -60, at: base)
        _ = engine.ingest(rssi: -61, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -62, at: base.addingTimeInterval(2))

        XCTAssertNil(engine.noteMissingSignal(at: base.addingTimeInterval(11)))

        let transition = engine.noteMissingSignal(at: base.addingTimeInterval(12))

        XCTAssertEqual(transition?.action, .lock)
        XCTAssertEqual(transition?.reason, "signal-lost")
    }

    func testStrongSignalWakesFromLockedState() {
        var engine = BoundaryEngine(settings: .default)
        let base = Date(timeIntervalSince1970: 4_000)

        _ = engine.ingest(rssi: -50, at: base)
        _ = engine.ingest(rssi: -52, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -51, at: base.addingTimeInterval(2))
        _ = engine.ingest(rssi: -92, at: base.addingTimeInterval(3))
        _ = engine.ingest(rssi: -94, at: base.addingTimeInterval(4))
        _ = engine.ingest(rssi: -96, at: base.addingTimeInterval(5))

        let wake = engine.ingest(rssi: -45, at: base.addingTimeInterval(6))

        XCTAssertEqual(wake?.action, .wakeDisplay)
        XCTAssertEqual(wake?.newState, .unlocked)
    }
}
```

- [ ] **Step 2: Run the boundary tests and verify they fail**

Run:

```bash
swift test --filter BoundaryEngineTests
```

Expected: FAIL with missing `BoundaryEngine` symbols

- [ ] **Step 3: Implement the boundary engine**

`Sources/ZoneCore/BoundaryEngine.swift`

```swift
import Foundation

public enum BoundaryState: String, Codable, Equatable, Sendable {
    case unknown
    case unlocked
    case locked
}

public enum BoundaryAction: String, Equatable, Sendable {
    case lock
    case wakeDisplay
}

public struct BoundaryTransition: Equatable, Sendable {
    public let previousState: BoundaryState
    public let newState: BoundaryState
    public let action: BoundaryAction?
    public let reason: String
    public let averageRSSI: Double?
}

public struct BoundaryEngine: Sendable {
    private let minimumPresenceSamples = 3
    private let lockThreshold: Int
    private let wakeThreshold: Int
    private let signalLossTimeout: TimeInterval
    private let windowSize: Int

    public private(set) var state: BoundaryState = .unknown
    public private(set) var samples: [Int] = []
    public private(set) var lastSeenAt: Date?
    public private(set) var missingSince: Date?

    public init(settings: ZoneSettings) {
        self.lockThreshold = settings.lockThreshold
        self.wakeThreshold = settings.wakeThreshold
        self.signalLossTimeout = settings.signalLossTimeout
        self.windowSize = settings.slidingWindowSize
    }

    public mutating func ingest(rssi: Int, at date: Date) -> BoundaryTransition? {
        samples.append(rssi)
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }

        lastSeenAt = date
        missingSince = nil

        let average = averageRSSI
        let previousState = state

        if state == .unknown, samples.count >= minimumPresenceSamples {
            state = .unlocked
            return BoundaryTransition(
                previousState: previousState,
                newState: state,
                action: nil,
                reason: "presence-confirmed",
                averageRSSI: average
            )
        }

        guard let average else { return nil }

        if state == .unlocked, average < Double(lockThreshold) {
            state = .locked
            return BoundaryTransition(
                previousState: previousState,
                newState: state,
                action: .lock,
                reason: "weak-signal",
                averageRSSI: average
            )
        }

        if state == .locked, average > Double(wakeThreshold) {
            state = .unlocked
            return BoundaryTransition(
                previousState: previousState,
                newState: state,
                action: .wakeDisplay,
                reason: "strong-signal",
                averageRSSI: average
            )
        }

        return nil
    }

    public mutating func noteMissingSignal(at date: Date) -> BoundaryTransition? {
        if missingSince == nil {
            missingSince = date
            return nil
        }

        guard state == .unlocked, let missingSince else { return nil }
        let missingDuration = date.timeIntervalSince(missingSince)
        guard missingDuration >= signalLossTimeout else { return nil }

        let previousState = state
        state = .locked

        return BoundaryTransition(
            previousState: previousState,
            newState: state,
            action: .lock,
            reason: "signal-lost",
            averageRSSI: averageRSSI
        )
    }

    public var averageRSSI: Double? {
        guard samples.isEmpty == false else { return nil }
        return Double(samples.reduce(0, +)) / Double(samples.count)
    }
}
```

- [ ] **Step 4: Run the full core test suite**

Run:

```bash
swift test
```

Expected: PASS

- [ ] **Step 5: Commit the boundary engine**

Run:

```bash
git add Sources/ZoneCore/BoundaryEngine.swift Tests/ZoneCoreTests/BoundaryEngineTests.swift
git commit -m "feat: add RSSI boundary engine"
```

### Task 4: Implement Settings Persistence And Diagnostics With TDD

**Files:**
- Create: `Sources/ZoneCore/DiagnosticsBuffer.swift`
- Create: `Sources/ZoneCore/ZoneSettingsStore.swift`
- Create: `Tests/ZoneCoreTests/DiagnosticsBufferTests.swift`
- Create: `Tests/ZoneCoreTests/ZoneSettingsStoreTests.swift`

- [ ] **Step 1: Write the failing diagnostics and persistence tests**

```swift
import XCTest
@testable import ZoneCore

final class DiagnosticsBufferTests: XCTestCase {
    func testBufferKeepsNewestEntriesOnly() {
        var buffer = DiagnosticsBuffer(capacity: 2)

        buffer.append(level: .info, message: "one", at: Date(timeIntervalSince1970: 1))
        buffer.append(level: .warning, message: "two", at: Date(timeIntervalSince1970: 2))
        buffer.append(level: .error, message: "three", at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(buffer.entries.map(\.message), ["three", "two"])
    }
}

final class ZoneSettingsStoreTests: XCTestCase {
    func testStoreReturnsDefaultsForEmptySuite() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = ZoneSettingsStore(defaults: defaults)

        XCTAssertEqual(store.load(), .default)
    }

    func testStorePersistsUpdatedSettings() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = ZoneSettingsStore(defaults: defaults)

        let updated = ZoneSettings(
            selectedDevice: SelectedDevice(
                stableID: "token",
                addressString: "AA-BB",
                displayName: "Desk Phone",
                majorDeviceClass: 2
            ),
            lockThreshold: -82,
            wakeThreshold: -52,
            signalLossTimeout: 8,
            slidingWindowSize: 6,
            launchAtLogin: true
        )

        try store.save(updated)

        XCTAssertEqual(store.load(), updated)
    }
}
```

- [ ] **Step 2: Run the new tests and confirm failure**

Run:

```bash
swift test --filter "DiagnosticsBufferTests|ZoneSettingsStoreTests"
```

Expected: FAIL with missing `DiagnosticsBuffer` or `ZoneSettingsStore`

- [ ] **Step 3: Implement diagnostics and persistence**

`Sources/ZoneCore/DiagnosticsBuffer.swift`

```swift
import Foundation

public struct DiagnosticEntry: Identifiable, Equatable, Sendable {
    public enum Level: String, Codable, Sendable {
        case info
        case warning
        case error
    }

    public let id: UUID
    public let timestamp: Date
    public let level: Level
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: Level,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct DiagnosticsBuffer: Sendable {
    private let capacity: Int
    public private(set) var entries: [DiagnosticEntry] = []

    public init(capacity: Int = 50) {
        self.capacity = capacity
    }

    public mutating func append(
        level: DiagnosticEntry.Level,
        message: String,
        at date: Date = Date()
    ) {
        entries.insert(DiagnosticEntry(timestamp: date, level: level, message: message), at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }
}
```

`Sources/ZoneCore/ZoneSettingsStore.swift`

```swift
import Foundation

public final class ZoneSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "zone.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ZoneSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        return (try? JSONDecoder().decode(ZoneSettings.self, from: data)) ?? .default
    }

    public func save(_ settings: ZoneSettings) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run the full core suite again**

Run:

```bash
swift test
```

Expected: PASS

- [ ] **Step 5: Commit the supporting core types**

Run:

```bash
git add Sources/ZoneCore/DiagnosticsBuffer.swift Sources/ZoneCore/ZoneSettingsStore.swift Tests/ZoneCoreTests/DiagnosticsBufferTests.swift Tests/ZoneCoreTests/ZoneSettingsStoreTests.swift
git commit -m "feat: add ZoneCore persistence and diagnostics"
```

### Task 5: Make The AppModel Testable And Wire The Settings UI

**Files:**
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Sources/SettingsView.swift`
- Modify: `App/Sources/StatusMenuContent.swift`
- Modify: `App/Sources/DiagnosticsView.swift`
- Modify: `project.yml`
- Create: `App/Sources/BluetoothSupport.swift`
- Create: `App/Sources/SystemServices.swift`
- Create: `App/Tests/AppModelTests.swift`

- [ ] **Step 1: Write the failing AppModel tests**

```swift
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
```

- [ ] **Step 2: Run the app tests and verify they fail**

Run:

```bash
xcodegen generate
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
```

Expected: FAIL because the `ZoneTests` target and the repository/service symbols do not exist yet

- [ ] **Step 3: Add protocols, test doubles, and the first real AppModel wiring**

`project.yml`

```yaml
name: Zone
options:
  bundleIdPrefix: com.pengdengke
configs:
  Debug: debug
  Release: release
packages:
  ZoneCore:
    path: .
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  Zone:
    type: application
    platform: macOS
    sources:
      - App/Sources
    info:
      properties:
        CFBundleDisplayName: Zone
        LSUIElement: true
        NSBluetoothAlwaysUsageDescription: Zone reads Bluetooth signal strength from your selected device to decide when to lock or wake your Mac.
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.pengdengke.Zone
        PRODUCT_NAME: Zone
        SWIFT_VERSION: "6.0"
    dependencies:
      - package: ZoneCore
        product: ZoneCore
  ZoneTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - App/Tests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.pengdengke.ZoneTests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Zone.app/Contents/MacOS/Zone"
    dependencies:
      - target: Zone
      - package: ZoneCore
        product: ZoneCore
schemes:
  Zone:
    build:
      targets:
        Zone: all
        ZoneTests: [test]
    test:
      targets:
        - ZoneTests
```

`App/Sources/BluetoothSupport.swift`

```swift
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
```

`App/Sources/SystemServices.swift`

```swift
import Foundation

protocol SystemActionPerforming {
    func lockScreen() throws
    func wakeDisplay() throws
}

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    var statusText: String { get }
}

protocol AccessibilityPermissionProviding {
    var isTrusted: Bool { get }
    func promptIfNeeded()
}

struct PreviewSystemActions: SystemActionPerforming {
    func lockScreen() throws {}
    func wakeDisplay() throws {}
}

struct PreviewLoginItemController: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {}
    var statusText: String { "Not Registered" }
}

struct PreviewAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool { true }
    func promptIfNeeded() {}
}
```

`App/Sources/AppModel.swift`

```swift
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
        bluetoothRepository: BluetoothRepository = PreviewBluetoothRepository(),
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
    }

    var menuBarSymbol: String {
        settings.selectedDevice == nil ? "dot.scope" : "lock.shield"
    }

    func refreshConnectedDevices() {
        connectedDevices = bluetoothRepository.connectedDevices()
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
```

`App/Sources/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                Picker("Use this token", selection: Binding(
                    get: { model.settings.selectedDevice?.stableID ?? "" },
                    set: { model.selectConnectedDevice(stableID: $0) }
                )) {
                    Text("None").tag("")
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName).tag(device.stableID)
                    }
                }

                Button("Refresh Connected Devices") {
                    model.refreshConnectedDevices()
                }
            }

            Section("Thresholds") {
                Text("Lock below: \(model.settings.lockThreshold) dBm")
                Text("Wake above: \(model.settings.wakeThreshold) dBm")
                Text("Signal loss timeout: \(Int(model.settings.signalLossTimeout)) s")
                Text("Sliding window: \(model.settings.slidingWindowSize)")
            }

            Section("Diagnostics") {
                DiagnosticsView(messages: model.diagnostics)
            }
        }
        .padding(16)
        .onAppear {
            model.refreshConnectedDevices()
        }
    }
}
```

- [ ] **Step 4: Run the app tests and the app build**

Run:

```bash
xcodegen generate
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
xcodebuild -project Zone.xcodeproj -scheme Zone -configuration Debug -destination 'platform=macOS' build
```

Expected: both commands end with `SUCCEEDED`

- [ ] **Step 5: Commit the app shell wiring**

Run:

```bash
git add project.yml App/Sources/AppModel.swift App/Sources/BluetoothSupport.swift App/Sources/SystemServices.swift App/Sources/SettingsView.swift App/Tests/AppModelTests.swift
git commit -m "feat: wire settings UI and app model"
```

### Task 6: Add Live IOBluetooth Device Enumeration And Permission Status

**Files:**
- Modify: `App/Sources/BluetoothSupport.swift`
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Tests/AppModelTests.swift`

- [ ] **Step 1: Extend the AppModel tests for unavailable devices**

```swift
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
```

- [ ] **Step 2: Run the app tests and confirm they fail**

Run:

```bash
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
```

Expected: FAIL because `AppModel.refreshConnectedDevices()` does not yet surface unavailable-device status

- [ ] **Step 3: Replace the preview repository with a live macOS implementation**

`App/Sources/BluetoothSupport.swift`

```swift
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
        let usableRSSI = rawRSSI == 127 ? nil : rawRSSI

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

    private static func summary(for device: IOBluetoothDevice) -> BluetoothDeviceSummary {
        BluetoothDeviceSummary(
            stableID: device.addressString,
            addressString: device.addressString,
            displayName: device.nameOrAddress,
            majorDeviceClass: UInt32(device.deviceClassMajor.rawValue)
        )
    }
}
```

`App/Sources/AppModel.swift`

```swift
// update the default repository argument
init(
    settingsStore: ZoneSettingsStore = ZoneSettingsStore(),
    bluetoothRepository: BluetoothRepository = MacBluetoothRepository(),
    systemActions: SystemActionPerforming = PreviewSystemActions(),
    loginItemController: LoginItemControlling = PreviewLoginItemController(),
    accessibilityPermission: AccessibilityPermissionProviding = PreviewAccessibilityPermission()
) {
    // existing body unchanged
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
```

- [ ] **Step 4: Re-run the app tests and a debug build**

Run:

```bash
xcodegen generate
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
xcodebuild -project Zone.xcodeproj -scheme Zone -configuration Debug -destination 'platform=macOS' build
```

Expected: both commands succeed

- [ ] **Step 5: Commit the live Bluetooth integration**

Run:

```bash
git add App/Sources/BluetoothSupport.swift App/Sources/AppModel.swift App/Tests/AppModelTests.swift
git commit -m "feat: integrate macOS bluetooth device enumeration"
```

### Task 7: Add Polling, Boundary Decisions, Lock/Wake Actions, And Diagnostics

**Files:**
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Sources/SystemServices.swift`
- Modify: `App/Sources/StatusMenuContent.swift`
- Modify: `App/Sources/SettingsView.swift`
- Modify: `App/Sources/DiagnosticsView.swift`
- Modify: `App/Tests/AppModelTests.swift`

- [ ] **Step 1: Write the failing monitoring tests**

```swift
func testWeakSamplesTriggerSingleLockAction() async throws {
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
        settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
        bluetoothRepository: repository,
        systemActions: actions,
        loginItemController: TestLoginItemController(),
        accessibilityPermission: TestAccessibilityPermission()
    )

    model.refreshConnectedDevices()
    model.selectConnectedDevice(stableID: "token")

    for offset in 0 ..< 6 {
        model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
    }

    XCTAssertEqual(actions.lockCalls, 1)
}

func testStrongSamplesWakeAfterLockedState() async throws {
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
                BluetoothDeviceReading(isConnected: true, rawRSSI: -40)
            ]
        ]
    )
    let actions = TestSystemActions()
    let model = AppModel(
        settingsStore: ZoneSettingsStore(defaults: UserDefaults(suiteName: #function)!),
        bluetoothRepository: repository,
        systemActions: actions,
        loginItemController: TestLoginItemController(),
        accessibilityPermission: TestAccessibilityPermission()
    )

    model.refreshConnectedDevices()
    model.selectConnectedDevice(stableID: "token")

    for offset in 0 ..< 7 {
        model.poll(at: Date(timeIntervalSince1970: TimeInterval(offset)))
    }

    XCTAssertEqual(actions.lockCalls, 1)
    XCTAssertEqual(actions.wakeCalls, 1)
}
```

- [ ] **Step 2: Run the app tests and confirm they fail**

Run:

```bash
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
```

Expected: FAIL because `AppModel` does not yet poll, track boundary state, or call actions

- [ ] **Step 3: Add polling, diagnostics, and real system actions**

`App/Sources/SystemServices.swift`

```swift
import ApplicationServices
import Foundation
import IOKit.pwr_mgt
import ServiceManagement

protocol SystemActionPerforming {
    func lockScreen() throws
    func wakeDisplay() throws
}

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    var statusText: String { get }
}

protocol AccessibilityPermissionProviding {
    var isTrusted: Bool { get }
    func promptIfNeeded()
}

enum SystemActionError: Error {
    case accessibilityDenied
    case eventSourceUnavailable
    case wakeFailed(Int32)
}

struct LiveSystemActions: SystemActionPerforming {
    func lockScreen() throws {
        guard AXIsProcessTrusted() else {
            throw SystemActionError.accessibilityDenied
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw SystemActionError.eventSourceUnavailable
        }

        let keyCode: CGKeyCode = 12
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = [.maskCommand, .maskControl]
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = [.maskCommand, .maskControl]

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    func wakeDisplay() throws {
        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity(
            "Zone Wake Display" as CFString,
            IOPMUserActiveType(kIOPMUserActiveLocal),
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw SystemActionError.wakeFailed(result)
        }

        IOPMAssertionRelease(assertionID)
    }
}

struct LiveAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
```

`App/Sources/AppModel.swift`

```swift
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

        let loaded = settingsStore.load()
        self.settings = loaded
        self.boundaryEngine = BoundaryEngine(settings: loaded)
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

    func refreshConnectedDevices() {
        connectedDevices = bluetoothRepository.connectedDevices()

        if let selected = settings.selectedDevice,
           bluetoothRepository.currentReading(for: selected) == nil {
            statusLine = "Device Unavailable"
            record(.warning, "Selected device is no longer known to macOS.")
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
        boundaryEngine = BoundaryEngine(settings: settings)
        try? settingsStore.save(settings)
        record(.info, "Selected device: \(match.displayName)")
        startPolling()
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
        statusLine = "Monitoring"
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
            statusLine = "Monitoring"
            record(.info, "Manual wake executed.")
        } catch {
            record(.error, "Wake failed: \(error)")
        }
    }

    func poll(at date: Date = Date()) {
        guard let selected = settings.selectedDevice else {
            statusLine = "Not Configured"
            return
        }

        guard let reading = bluetoothRepository.currentReading(for: selected) else {
            statusLine = "Device Unavailable"
            record(.warning, "Configured device is unavailable.")
            return
        }

        if reading.isConnected, let rawRSSI = reading.rawRSSI {
            latestRSSIText = "\(rawRSSI) dBm"
            record(.info, "RSSI sample: \(rawRSSI) dBm")
            if let transition = boundaryEngine.ingest(rssi: rawRSSI, at: date) {
                apply(transition)
            }
        } else if let transition = boundaryEngine.noteMissingSignal(at: date) {
            apply(transition)
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
                statusLine = "Monitoring"
                record(.error, "Automatic lock failed: \(error)")
                return
            }
        case .wakeDisplay:
            do {
                try systemActions.wakeDisplay()
                statusLine = "Monitoring"
            } catch {
                record(.error, "Automatic wake failed: \(error)")
                return
            }
        case .none:
            statusLine = transition.newState == .locked ? "Locked" : "Monitoring"
        }

        record(.info, "Boundary transition: \(transition.reason)")
    }

    private func record(_ level: DiagnosticEntry.Level, _ message: String) {
        diagnosticsBuffer.append(level: level, message: message)
        diagnostics = diagnosticsBuffer.entries.map { "[\($0.level.rawValue.uppercased())] \($0.message)" }
    }

    private func persistSettings() {
        boundaryEngine = BoundaryEngine(settings: settings)
        try? settingsStore.save(settings)
    }
}
```

`App/Sources/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                Picker("Use this token", selection: Binding(
                    get: { model.settings.selectedDevice?.stableID ?? "" },
                    set: { model.selectConnectedDevice(stableID: $0) }
                )) {
                    Text("None").tag("")
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName).tag(device.stableID)
                    }
                }

                Button("Refresh Connected Devices") {
                    model.refreshConnectedDevices()
                }
            }

            Section("Thresholds") {
                Stepper("Lock below: \(model.settings.lockThreshold) dBm", value: Binding(
                    get: { model.settings.lockThreshold },
                    set: { model.updateLockThreshold($0) }
                ), in: -100 ... -40)

                Stepper("Wake above: \(model.settings.wakeThreshold) dBm", value: Binding(
                    get: { model.settings.wakeThreshold },
                    set: { model.updateWakeThreshold($0) }
                ), in: -80 ... -20)

                Stepper("Signal loss timeout: \(Int(model.settings.signalLossTimeout)) s", value: Binding(
                    get: { Int(model.settings.signalLossTimeout) },
                    set: { model.updateSignalLossTimeout(Double($0)) }
                ), in: 3 ... 30)

                Stepper("Sliding window: \(model.settings.slidingWindowSize)", value: Binding(
                    get: { model.settings.slidingWindowSize },
                    set: { model.updateSlidingWindowSize($0) }
                ), in: 3 ... 10)
            }

            Section("Diagnostics") {
                DiagnosticsView(messages: model.diagnostics)
            }
        }
        .padding(16)
        .onAppear {
            model.refreshConnectedDevices()
        }
    }
}
```

- [ ] **Step 4: Run tests and build after monitoring integration**

Run:

```bash
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
xcodebuild -project Zone.xcodeproj -scheme Zone -configuration Debug -destination 'platform=macOS' build
```

Expected: both commands succeed

- [ ] **Step 5: Commit monitoring and system actions**

Run:

```bash
git add App/Sources/AppModel.swift App/Sources/SystemServices.swift App/Sources/StatusMenuContent.swift App/Sources/SettingsView.swift App/Sources/DiagnosticsView.swift App/Tests/AppModelTests.swift
git commit -m "feat: add monitoring loop and system actions"
```

### Task 8: Add Launch-At-Login And DMG Packaging

**Files:**
- Modify: `App/Sources/SystemServices.swift`
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Sources/SettingsView.swift`
- Modify: `project.yml`
- Create: `App/Resources/Assets.xcassets/Contents.json`
- Create: `scripts/generate_app_icon.swift`
- Create: `scripts/build_dmg.sh`

- [ ] **Step 1: Add the failing login-item test**

```swift
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
```

- [ ] **Step 2: Run the app tests and confirm failure**

Run:

```bash
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests
```

Expected: FAIL because `setLaunchAtLogin(_:)` is not implemented

- [ ] **Step 3: Add the live login-item controller, icon generator, and DMG build script**

`App/Sources/SystemServices.swift`

```swift
import ApplicationServices
import Foundation
import IOKit.pwr_mgt
import ServiceManagement

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    var statusText: String { get }
}

struct LiveLoginItemController: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires Approval"
        case .notFound:
            return "Not Found"
        case .notRegistered:
            return "Not Registered"
        @unknown default:
            return "Unknown"
        }
    }
}
```

`App/Sources/AppModel.swift`

```swift
// update the default login item dependency
init(
    settingsStore: ZoneSettingsStore = ZoneSettingsStore(),
    bluetoothRepository: BluetoothRepository = MacBluetoothRepository(),
    systemActions: SystemActionPerforming = LiveSystemActions(),
    loginItemController: LoginItemControlling = LiveLoginItemController(),
    accessibilityPermission: AccessibilityPermissionProviding = LiveAccessibilityPermission()
) {
    // existing body unchanged
}

func setLaunchAtLogin(_ enabled: Bool) {
    do {
        try loginItemController.setEnabled(enabled)
        settings.launchAtLogin = enabled
        try settingsStore.save(settings)
        record(.info, "Launch at login: \(enabled ? "enabled" : "disabled")")
    } catch {
        record(.error, "Login item update failed: \(error)")
    }
}

var bluetoothPermissionStatusText: String {
    bluetoothRepository.bluetoothPermissionStatusText
}

var accessibilityStatusText: String {
    accessibilityPermission.isTrusted ? "Allowed" : "Needs Approval"
}

var loginItemStatusText: String {
    loginItemController.statusText
}
```

`App/Sources/SettingsView.swift`

```swift
Section("Permissions & Startup") {
    Text("Bluetooth access: \(model.bluetoothPermissionStatusText)")
    Text("Accessibility: \(model.accessibilityStatusText)")
    Text("Login item: \(model.loginItemStatusText)")
    Toggle(
        "Launch at login",
        isOn: Binding(
            get: { model.settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    )
}
```

`project.yml`

```yaml
name: Zone
options:
  bundleIdPrefix: com.pengdengke
configs:
  Debug: debug
  Release: release
packages:
  ZoneCore:
    path: .
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  Zone:
    type: application
    platform: macOS
    sources:
      - App/Sources
    resources:
      - App/Resources
    info:
      properties:
        CFBundleDisplayName: Zone
        LSUIElement: true
        NSBluetoothAlwaysUsageDescription: Zone reads Bluetooth signal strength from your selected device to decide when to lock or wake your Mac.
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.pengdengke.Zone
        PRODUCT_NAME: Zone
        SWIFT_VERSION: "6.0"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    dependencies:
      - package: ZoneCore
        product: ZoneCore
  ZoneTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - App/Tests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.pengdengke.ZoneTests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Zone.app/Contents/MacOS/Zone"
    dependencies:
      - target: Zone
      - package: ZoneCore
        product: ZoneCore
schemes:
  Zone:
    build:
      targets:
        Zone: all
        ZoneTests: [test]
    test:
      targets:
        - ZoneTests
```

`App/Resources/Assets.xcassets/Contents.json`

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`scripts/generate_app_icon.swift`

```swift
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: swift scripts/generate_app_icon.swift <AppIcon.appiconset>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconNames: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func makeImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor(calibratedRed: 0.08, green: 0.44, blue: 0.73, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.22, yRadius: size * 0.22).fill()

    NSColor.white.setStroke()
    let outer = NSBezierPath()
    outer.lineWidth = size * 0.08
    outer.appendOval(in: NSRect(x: size * 0.2, y: size * 0.2, width: size * 0.6, height: size * 0.6))
    outer.stroke()

    let inner = NSBezierPath()
    inner.lineWidth = size * 0.08
    inner.appendOval(in: NSRect(x: size * 0.35, y: size * 0.35, width: size * 0.3, height: size * 0.3))
    inner.stroke()

    image.unlockFocus()
    return image
}

for (name, size) in iconNames {
    let image = makeImage(size: size)
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fatalError("failed to render \(name)")
    }

    try png.write(to: outputURL.appendingPathComponent(name))
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contents.data(using: .utf8)!.write(to: outputURL.appendingPathComponent("Contents.json"))
```

`scripts/build_dmg.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
ARCHIVE_PATH="$ROOT/build/Zone.xcarchive"
APP_PATH="$ROOT/build/Zone.app"
DMG_PATH="$ROOT/build/Zone.dmg"

swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
xcodegen generate
xcodebuild \
  -project "$ROOT/Zone.xcodeproj" \
  -scheme Zone \
  -configuration Release \
  -destination 'platform=macOS' \
  archive \
  -archivePath "$ARCHIVE_PATH"

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Zone.app" "$APP_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname Zone -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
```

- [ ] **Step 4: Run the full verification flow**

Run:

```bash
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test
swift scripts/generate_app_icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset
chmod +x scripts/build_dmg.sh
./scripts/build_dmg.sh
```

Expected:
- tests pass
- icon files appear under `App/Resources/Assets.xcassets/AppIcon.appiconset`
- `build/Zone.dmg` exists

- [ ] **Step 5: Commit the release tooling**

Run:

```bash
git add project.yml App/Sources/SystemServices.swift App/Sources/AppModel.swift App/Sources/SettingsView.swift App/Resources/Assets.xcassets/Contents.json scripts/generate_app_icon.swift scripts/build_dmg.sh
git commit -m "feat: add launch item support and dmg packaging"
```
