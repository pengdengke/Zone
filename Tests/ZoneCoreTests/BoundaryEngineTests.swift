import Foundation
import XCTest
@testable import ZoneCore

final class BoundaryEngineTests: XCTestCase {
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

    func testThreeSamplesConfirmPresenceWithoutLocking() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 1_000)

        XCTAssertNil(engine.ingest(rssi: -60, at: base))
        XCTAssertNil(engine.ingest(rssi: -62, at: base.addingTimeInterval(1)))

        let transition = engine.ingest(rssi: -61, at: base.addingTimeInterval(2))

        XCTAssertEqual(transition?.newState, .unlocked)
        XCTAssertNil(transition?.action)
        XCTAssertEqual(transition?.reason, "presence-confirmed")
    }

    func testSmallWindowsConfirmPresenceWithoutWaitingForThreeSamples() {
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

        XCTAssertEqual(oneSampleTransition?.newState, .unlocked)
        XCTAssertEqual(oneSampleTransition?.reason, "presence-confirmed")

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

        XCTAssertNil(twoSampleEngine.ingest(rssi: -60, at: base))
        let twoSampleTransition = twoSampleEngine.ingest(rssi: -60, at: base.addingTimeInterval(1))

        XCTAssertEqual(twoSampleTransition?.newState, .unlocked)
        XCTAssertEqual(twoSampleTransition?.reason, "presence-confirmed")
    }

    func testWeakStartupAverageStaysUnknownWithoutLocking() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 1_800)

        XCTAssertNil(engine.ingest(rssi: -96, at: base))
        XCTAssertNil(engine.ingest(rssi: -97, at: base.addingTimeInterval(1)))

        let transition = engine.ingest(rssi: -98, at: base.addingTimeInterval(2))

        XCTAssertNil(transition)
        XCTAssertEqual(engine.state, .unknown)
    }

    func testWeakAverageLocksOnlyOnce() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 2_000)

        _ = engine.ingest(rssi: -50, at: base)
        _ = engine.ingest(rssi: -52, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -51, at: base.addingTimeInterval(2))
        _ = engine.ingest(rssi: -92, at: base.addingTimeInterval(3))
        _ = engine.ingest(rssi: -94, at: base.addingTimeInterval(4))

        let firstLock = engine.ingest(rssi: -96, at: base.addingTimeInterval(5))
        let secondLock = engine.ingest(rssi: -97, at: base.addingTimeInterval(6))

        XCTAssertEqual(firstLock?.action, .lock)
        XCTAssertEqual(firstLock?.newState, .locked)
        XCTAssertNil(secondLock)
    }

    func testMissingSignalLocksAfterConfiguredTimeout() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 3_000)

        _ = engine.ingest(rssi: -60, at: base)
        _ = engine.ingest(rssi: -61, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -62, at: base.addingTimeInterval(2))

        XCTAssertNil(engine.noteMissingSignal(at: base.addingTimeInterval(11)))
        XCTAssertNil(engine.noteMissingSignal(at: base.addingTimeInterval(20)))

        let transition = engine.noteMissingSignal(at: base.addingTimeInterval(21))

        XCTAssertEqual(transition?.action, .lock)
        XCTAssertEqual(transition?.reason, "signal-lost")
        XCTAssertEqual(transition?.newState, .locked)
    }

    func testStrongSignalWakesFromLockedStateOnce() {
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

        XCTAssertEqual(wake?.action, .wakeDisplay)
        XCTAssertEqual(wake?.newState, .unlocked)
        XCTAssertNil(duplicateWake)
    }

    func testSignalLossLockDropsStaleSamplesBeforeEvaluatingWake() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 4_500)

        _ = engine.ingest(rssi: -45, at: base)
        _ = engine.ingest(rssi: -45, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -45, at: base.addingTimeInterval(2))

        XCTAssertNil(engine.noteMissingSignal(at: base.addingTimeInterval(13)))
        XCTAssertNil(engine.noteMissingSignal(at: base.addingTimeInterval(20)))

        let lock = engine.noteMissingSignal(at: base.addingTimeInterval(24))
        let wakeAttempt = engine.ingest(rssi: -70, at: base.addingTimeInterval(25))

        XCTAssertEqual(lock?.action, .lock)
        XCTAssertEqual(lock?.reason, "signal-lost")
        XCTAssertNil(wakeAttempt)
        XCTAssertEqual(engine.state, .locked)
    }

    func testForceLockedStateClearsStrongSamplesBeforeWakeEvaluation() {
        var engine = BoundaryEngine(settings: makeSettings())
        let base = Date(timeIntervalSince1970: 5_000)

        _ = engine.ingest(rssi: -40, at: base)
        _ = engine.ingest(rssi: -40, at: base.addingTimeInterval(1))
        _ = engine.ingest(rssi: -40, at: base.addingTimeInterval(2))

        engine.forceLockedState(at: base.addingTimeInterval(3))
        let wakeAttempt = engine.ingest(rssi: -70, at: base.addingTimeInterval(4))

        XCTAssertNil(wakeAttempt)
        XCTAssertEqual(engine.state, .locked)
        XCTAssertEqual(engine.samples, [-70])
    }

    func testInvalidWakeThresholdNormalizesAboveLockThreshold() {
        var engine = BoundaryEngine(
            settings: ZoneSettings(
                selectedDevice: nil,
                lockThreshold: -60,
                wakeThreshold: -70,
                signalLossTimeout: 10,
                slidingWindowSize: 3,
                launchAtLogin: false
            )
        )
        let base = Date(timeIntervalSince1970: 5_500)

        engine.forceLockedState(at: base)
        let wakeAttempt = engine.ingest(rssi: -65, at: base.addingTimeInterval(1))

        XCTAssertNil(wakeAttempt)
        XCTAssertEqual(engine.state, .locked)
    }
}
