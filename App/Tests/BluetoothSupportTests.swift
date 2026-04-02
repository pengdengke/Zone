import XCTest
@testable import Zone
import ZoneCore

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
}
