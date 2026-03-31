import Foundation
import Testing
@testable import ZoneCore

@Suite
struct ZoneSettingsStoreTests {
    @Test
    func storeReturnsDefaultsForEmptySuite() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = ZoneSettingsStore(defaults: defaults)

        #expect(store.load() == .default)
    }

    @Test
    func storePersistsUpdatedSettings() throws {
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

        #expect(store.load() == updated)
    }
}
