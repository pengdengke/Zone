import XCTest
@testable import Zone
import ZoneCore

final class MockBLEScanner: BLEScanning {
    var latestReading: BLEReading?
    var startScanCallCount = 0
    var stopScanCallCount = 0
    var lastDeviceName: String?

    func startScanning(forDeviceName name: String) {
        startScanCallCount += 1
        lastDeviceName = name
    }

    func stopScanning() {
        stopScanCallCount += 1
    }
}

final class TestBluetoothPermissionController: BluetoothPermissionControlling {
    private(set) var prepareCalls = 0
    var status: BluetoothAuthorizationStatus

    init(status: BluetoothAuthorizationStatus) {
        self.status = status
    }

    func prepareForAccess() {
        prepareCalls += 1
    }
}

final class BluetoothSupportTests: XCTestCase {
    func testConnectedDevicesPrepareBluetoothAccessBeforeEnumeration() {
        let permissionController = TestBluetoothPermissionController(status: .notDetermined)
        let repository = MacBluetoothRepository(permissionController: permissionController)

        let devices = repository.connectedDevices()

        XCTAssertEqual(permissionController.prepareCalls, 1)
        XCTAssertTrue(devices.isEmpty)
        XCTAssertEqual(repository.bluetoothPermissionStatusText, "Not Determined")
    }

    func testCurrentReadingReturnsNilUntilBluetoothAccessIsAllowed() {
        let permissionController = TestBluetoothPermissionController(status: .restricted)
        let repository = MacBluetoothRepository(permissionController: permissionController)
        let selectedDevice = SelectedDevice(
            stableID: "token",
            addressString: "AA-BB",
            displayName: "Desk Phone",
            majorDeviceClass: 2
        )

        let reading = repository.currentReading(for: selectedDevice)

        XCTAssertEqual(permissionController.prepareCalls, 1)
        XCTAssertNil(reading)
        XCTAssertEqual(repository.bluetoothPermissionStatusText, "Restricted")
    }

    func testBLEReadingIsNilBeforeFallbackStarted() {
        let permissionController = TestBluetoothPermissionController(status: .allowed)
        let mockBLE = MockBLEScanner()
        let repository = MacBluetoothRepository(
            permissionController: permissionController,
            bleScanner: mockBLE
        )

        XCTAssertNil(repository.bleReading)
    }

    func testStartBLEFallbackCallsScanner() {
        let permissionController = TestBluetoothPermissionController(status: .allowed)
        let mockBLE = MockBLEScanner()
        let repository = MacBluetoothRepository(
            permissionController: permissionController,
            bleScanner: mockBLE
        )
        let device = SelectedDevice(
            stableID: "token",
            addressString: "AA-BB",
            displayName: "My iPhone",
            majorDeviceClass: 2
        )

        repository.startBLEFallback(for: device)

        XCTAssertEqual(mockBLE.startScanCallCount, 1)
        XCTAssertEqual(mockBLE.lastDeviceName, "My iPhone")
    }

    func testStopBLEFallbackCallsScanner() {
        let permissionController = TestBluetoothPermissionController(status: .allowed)
        let mockBLE = MockBLEScanner()
        let repository = MacBluetoothRepository(
            permissionController: permissionController,
            bleScanner: mockBLE
        )

        repository.stopBLEFallback()

        XCTAssertEqual(mockBLE.stopScanCallCount, 1)
    }

    func testBLEReadingReturnsReadingFromScanner() {
        let permissionController = TestBluetoothPermissionController(status: .allowed)
        let mockBLE = MockBLEScanner()
        mockBLE.latestReading = BLEReading(
            peripheralID: UUID(),
            rssi: -55,
            deviceName: "iPhone"
        )
        let repository = MacBluetoothRepository(
            permissionController: permissionController,
            bleScanner: mockBLE
        )

        let reading = repository.bleReading

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.rawRSSI, -55)
        XCTAssertTrue(reading?.isConnected ?? false)
    }
}
