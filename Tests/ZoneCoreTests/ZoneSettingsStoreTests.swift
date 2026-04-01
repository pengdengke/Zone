import Foundation
import XCTest
@testable import ZoneCore

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
            language: .simplifiedChinese,
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
