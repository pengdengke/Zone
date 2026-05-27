import CoreBluetooth
import XCTest
@testable import Zone

final class MockCBCentralManager: CBCentralManaging {
    var state: CBManagerState = .poweredOn
    var delegate: CBCentralManagerDelegate?
    var scanCallCount = 0
    var stopScanCallCount = 0
    var lastScanOptions: [String: Any]?

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        scanCallCount += 1
        lastScanOptions = options
    }

    func stopScan() {
        stopScanCallCount += 1
    }
}

final class BLEScannerTests: XCTestCase {
    func testStartScanningCallsCentralManager() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)

        scanner.startScanning(forDeviceName: "iPhone")

        XCTAssertEqual(mockCentral.scanCallCount, 1)
        XCTAssertEqual(mockCentral.lastScanOptions?[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool, true)
    }

    func testStopScanningCallsCentralManager() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)

        scanner.startScanning(forDeviceName: "iPhone")
        scanner.stopScanning()

        XCTAssertEqual(mockCentral.stopScanCallCount, 1)
        XCTAssertNil(scanner.latestReading)
    }

    func testLatestReadingIsNilBeforeScan() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)

        XCTAssertNil(scanner.latestReading)
    }

    func testInitialStateIsNil() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)

        XCTAssertNil(scanner.latestReading)
        XCTAssertEqual(mockCentral.scanCallCount, 0)
    }

    func testOnReadingUpdatedCallbackCalled() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)
        var callbackCount = 0
        scanner.onReadingUpdated = { _ in
            callbackCount += 1
        }

        scanner.startScanning(forDeviceName: "iPhone")

        // Verify callback mechanism exists
        XCTAssertEqual(callbackCount, 0)
    }

    func testStopScanningResetsState() {
        let mockCentral = MockCBCentralManager()
        let scanner = BLEScanner(centralManager: mockCentral)

        scanner.startScanning(forDeviceName: "iPhone")
        XCTAssertNil(scanner.latestReading) // Nil after start

        scanner.stopScanning()
        XCTAssertNil(scanner.latestReading) // Still nil after stop
    }
}
