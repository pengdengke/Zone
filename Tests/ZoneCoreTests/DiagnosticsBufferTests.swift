import Foundation
import XCTest
@testable import ZoneCore

final class DiagnosticsBufferTests: XCTestCase {
    func testBufferKeepsNewestEntriesOnly() {
        var buffer = DiagnosticsBuffer(capacity: 2)

        buffer.append(level: .info, message: "one", at: Date(timeIntervalSince1970: 1))
        buffer.append(level: .warning, message: "two", at: Date(timeIntervalSince1970: 2))
        buffer.append(level: .error, message: "three", at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(buffer.entries.map(\.message), ["three", "two"])
    }

    func testNegativeCapacityDoesNotCrashOrKeepEntries() {
        var buffer = DiagnosticsBuffer(capacity: -1)

        buffer.append(level: .info, message: "one", at: Date(timeIntervalSince1970: 1))

        XCTAssertTrue(buffer.entries.isEmpty)
    }
}
