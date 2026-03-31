import Foundation
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

    func testIncompletePayloadDecodesWithDefaults() throws {
        let data = #"""
        {
          "selectedDevice": {
            "stableID": "AA-BB-CC",
            "addressString": "AA-BB-CC"
          },
          "lockThreshold": -81
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ZoneSettings.self, from: data)

        XCTAssertNil(decoded.selectedDevice)
        XCTAssertEqual(decoded.lockThreshold, -81)
        XCTAssertEqual(decoded.wakeThreshold, -55)
        XCTAssertEqual(decoded.signalLossTimeout, 10)
        XCTAssertEqual(decoded.slidingWindowSize, 5)
        XCTAssertFalse(decoded.launchAtLogin)
    }
}
