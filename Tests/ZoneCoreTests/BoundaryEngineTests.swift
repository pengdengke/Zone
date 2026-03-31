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
    func smallWindowsConfirmPresenceWithoutWaitingForThreeSamples() {
        let base = Date(timeIntervalSince1970: 1_500)

        var oneSampleEngine = BoundaryEngine(
            settings: ZoneSettings(
                selectedDevice: nil,
                lockThreshold: -85,
                wakeThreshold: -55,
                signalLossTimeout: 10,
                slidingWindowSize: 1,
                launchAtLogin: false
            )
        )
        let oneSampleTransition = oneSampleEngine.ingest(rssi: -60, at: base)

        #expect(oneSampleTransition?.newState == .unlocked)
        #expect(oneSampleTransition?.reason == "presence-confirmed")

        var twoSampleEngine = BoundaryEngine(
            settings: ZoneSettings(
                selectedDevice: nil,
                lockThreshold: -85,
                wakeThreshold: -55,
                signalLossTimeout: 10,
                slidingWindowSize: 2,
                launchAtLogin: false
            )
        )

        #expect(twoSampleEngine.ingest(rssi: -60, at: base) == nil)
        let twoSampleTransition = twoSampleEngine.ingest(rssi: -60, at: base.addingTimeInterval(1))

        #expect(twoSampleTransition?.newState == .unlocked)
        #expect(twoSampleTransition?.reason == "presence-confirmed")
    }

    @Test
    func weakStartupAverageStaysUnknownWithoutLocking() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 1_800)

        #expect(engine.ingest(rssi: -96, at: base) == nil)
        #expect(engine.ingest(rssi: -97, at: base.addingTimeInterval(1)) == nil)

        let transition = engine.ingest(rssi: -98, at: base.addingTimeInterval(2))

        #expect(transition == nil)
        #expect(engine.state == .unknown)
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
        #expect(engine.noteMissingSignal(at: base.addingTimeInterval(20)) == nil)

        let transition = engine.noteMissingSignal(at: base.addingTimeInterval(21))

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

    @Test
    func signalLossLockDropsStaleSamplesBeforeEvaluatingWake() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 4_500)

        _ = engine.ingest(rssi: -45, at: base)
        _ = engine.ingest(rssi: -45, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -45, at: base.addingTimeInterval(2))

        #expect(engine.noteMissingSignal(at: base.addingTimeInterval(13)) == nil)
        #expect(engine.noteMissingSignal(at: base.addingTimeInterval(20)) == nil)

        let lock = engine.noteMissingSignal(at: base.addingTimeInterval(24))
        let wakeAttempt = engine.ingest(rssi: -70, at: base.addingTimeInterval(25))

        #expect(lock?.action == .lock)
        #expect(lock?.reason == "signal-lost")
        #expect(wakeAttempt == nil)
        #expect(engine.state == .locked)
    }
}
