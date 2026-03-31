import Foundation

public enum BoundaryState: String, Codable, Equatable, Sendable {
    case unknown
    case unlocked
    case locked
}

public enum BoundaryAction: String, Codable, Equatable, Sendable {
    case lock
    case wakeDisplay
}

public struct BoundaryTransition: Equatable, Sendable {
    public let previousState: BoundaryState
    public let newState: BoundaryState
    public let action: BoundaryAction?
    public let reason: String
    public let averageRSSI: Double?

    public init(
        previousState: BoundaryState,
        newState: BoundaryState,
        action: BoundaryAction?,
        reason: String,
        averageRSSI: Double?
    ) {
        self.previousState = previousState
        self.newState = newState
        self.action = action
        self.reason = reason
        self.averageRSSI = averageRSSI
    }
}

public struct BoundaryEngine: Sendable {
    private let lockThreshold: Int
    private let wakeThreshold: Int
    private let signalLossTimeout: TimeInterval
    private let windowSize: Int

    public private(set) var state: BoundaryState = .unknown
    public private(set) var samples: [Int] = []
    public private(set) var lastSeenAt: Date?
    public private(set) var missingSince: Date?

    public init(settings: ZoneSettings) {
        self.lockThreshold = settings.lockThreshold
        self.wakeThreshold = settings.wakeThreshold
        self.signalLossTimeout = settings.signalLossTimeout
        self.windowSize = max(1, settings.slidingWindowSize)
    }

    public mutating func ingest(rssi: Int, at date: Date) -> BoundaryTransition? {
        appendSample(rssi)
        lastSeenAt = date
        missingSince = nil

        let average = averageRSSI
        let previousState = state

        if state == .unknown, samples.count >= minimumPresenceSamples {
            if let average, average < Double(lockThreshold) {
                state = .locked
                return BoundaryTransition(
                    previousState: previousState,
                    newState: state,
                    action: .lock,
                    reason: "weak-signal",
                    averageRSSI: average
                )
            } else {
                state = .unlocked
                return BoundaryTransition(
                    previousState: previousState,
                    newState: state,
                    action: nil,
                    reason: "presence-confirmed",
                    averageRSSI: average
                )
            }
        }

        guard let average else { return nil }

        if state == .unlocked, average < Double(lockThreshold) {
            state = .locked
            return BoundaryTransition(
                previousState: previousState,
                newState: state,
                action: .lock,
                reason: "weak-signal",
                averageRSSI: average
            )
        }

        if state == .locked, average > Double(wakeThreshold) {
            state = .unlocked
            return BoundaryTransition(
                previousState: previousState,
                newState: state,
                action: .wakeDisplay,
                reason: "strong-signal",
                averageRSSI: average
            )
        }

        return nil
    }

    public mutating func noteMissingSignal(at date: Date) -> BoundaryTransition? {
        guard state == .unlocked, let lastSeenAt else { return nil }
        guard date.timeIntervalSince(lastSeenAt) >= signalLossTimeout else { return nil }

        let previousState = state
        state = .locked
        samples.removeAll(keepingCapacity: true)
        missingSince = date

        return BoundaryTransition(
            previousState: previousState,
            newState: state,
            action: .lock,
            reason: "signal-lost",
            averageRSSI: averageRSSI
        )
    }

    public var averageRSSI: Double? {
        guard samples.isEmpty == false else { return nil }
        return Double(samples.reduce(0, +)) / Double(samples.count)
    }

    private var minimumPresenceSamples: Int {
        min(3, windowSize)
    }

    private mutating func appendSample(_ rssi: Int) {
        samples.append(rssi)
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }
    }
}
