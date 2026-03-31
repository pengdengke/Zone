import Foundation
import Testing
@testable import ZoneCore

@Suite
struct DiagnosticsBufferTests {
    @Test
    func bufferKeepsNewestEntriesOnly() {
        var buffer = DiagnosticsBuffer(capacity: 2)

        buffer.append(level: .info, message: "one", at: Date(timeIntervalSince1970: 1))
        buffer.append(level: .warning, message: "two", at: Date(timeIntervalSince1970: 2))
        buffer.append(level: .error, message: "three", at: Date(timeIntervalSince1970: 3))

        #expect(buffer.entries.map(\.message) == ["three", "two"])
    }
}
