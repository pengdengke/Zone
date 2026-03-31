import Foundation

public struct DiagnosticEntry: Identifiable, Equatable, Sendable {
    public enum Level: String, Codable, Sendable {
        case info
        case warning
        case error
    }

    public let id: UUID
    public let timestamp: Date
    public let level: Level
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: Level,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct DiagnosticsBuffer: Sendable {
    private let capacity: Int
    public private(set) var entries: [DiagnosticEntry] = []

    public init(capacity: Int = 50) {
        self.capacity = capacity
    }

    public mutating func append(
        level: DiagnosticEntry.Level,
        message: String,
        at date: Date = Date()
    ) {
        entries.insert(DiagnosticEntry(timestamp: date, level: level, message: message), at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }
}
