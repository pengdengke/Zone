import Foundation
import Testing
@testable import ZoneCore

@Suite
struct BoundaryEngineTests {
    private func makeSettings() -> ZoneSettings {
        ZoneSettings(
            selectedDevice: nil,
            lockThreshold: -85,
            wakeThreshold: -55,
            signalLossTimeout: 10,
            slidingWindowSize: 3,
            launchAtLogin: false
        )
    }

    @Test
    func threeSamplesConfirmPresenceWithoutLocking() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 1_000)

        #expect(engine.ingest(rssi: -60, at: base) == nil)
        #expect(engine.ingest(rssi: -62, at: base.addingTimeInterval(1)) == nil)

        let transition = engine.ingest(rssi: -61, at: base.addingTimeInterval(2))

        #expect(transition?.newState == .unlocked)
        #expect(transition?.action == nil)
        #expect(transition?.reason == "presence-confirmed")
    }

    @Test
    func weakAverageLocksOnlyOnce() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 2_000)

        _ = engine.ingest(rssi: -50, at: base)
        _ = engine.ingest(rssi: -52, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -51, at: base.addingTimeInterval(2))
        _ = engine.ingest(rssi: -92, at: base.addingTimeInterval(3))
        _ = engine.ingest(rssi: -94, at: base.addingTimeInterval(4))

        let firstLock = engine.ingest(rssi: -96, at: base.addingTimeInterval(5))
        let secondLock = engine.ingest(rssi: -97, at: base.addingTimeInterval(6))

        #expect(firstLock?.action == .lock)
        #expect(firstLock?.newState == .locked)
        #expect(secondLock == nil)
    }

    @Test
    func missingSignalLocksAfterConfiguredTimeout() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 3_000)

        _ = engine.ingest(rssi: -60, at: base)
        _ = engine.ingest(rssi: -61, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -62, at: base.addingTimeInterval(2))

        #expect(engine.noteMissingSignal(at: base.addingTimeInterval(11)) == nil)

        let transition = engine.noteMissingSignal(at: base.addingTimeInterval(12))

        #expect(transition?.action == .lock)
        #expect(transition?.reason == "signal-lost")
        #expect(transition?.newState == .locked)
    }

    @Test
    func strongSignalWakesFromLockedStateOnce() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 4_000)

        _ = engine.ingest(rssi: -50, at: base)
        _ = engine.ingest(rssi: -52, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -51, at: base.addingTimeInterval(2))
        _ = engine.ingest(rssi: -92, at: base.addingTimeInterval(3))
        _ = engine.ingest(rssi: -94, at: base.addingTimeInterval(4))
        _ = engine.ingest(rssi: -96, at: base.addingTimeInterval(5))

        _ = engine.ingest(rssi: -45, at: base.addingTimeInterval(6))
        _ = engine.ingest(rssi: -44, at: base.addingTimeInterval(7))

        let wake = engine.ingest(rssi: -43, at: base.addingTimeInterval(8))
        let duplicateWake = engine.ingest(rssi: -42, at: base.addingTimeInterval(9))

        #expect(wake?.action == .wakeDisplay)
        #expect(wake?.newState == .unlocked)
        #expect(duplicateWake == nil)
    }
}
