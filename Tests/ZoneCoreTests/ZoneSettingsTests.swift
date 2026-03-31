import Foundation
import Testing
@testable import ZoneCore

@Suite
struct ZoneSettingsTests {
    @Test
    func defaultSettingsMatchApprovedSpec() {
        let settings = ZoneSettings.default

        #expect(settings.selectedDevice == nil)
        #expect(settings.lockThreshold == -85)
        #expect(settings.wakeThreshold == -55)
        #expect(settings.signalLossTimeout == 10)
        #expect(settings.slidingWindowSize == 5)
        #expect(!settings.launchAtLogin)
    }

    @Test
    func selectedDeviceRoundTripsThroughCodable() throws {
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

        #expect(decoded == settings)
    }
}
