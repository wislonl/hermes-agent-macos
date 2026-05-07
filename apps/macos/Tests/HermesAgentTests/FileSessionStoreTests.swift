import XCTest
@testable import HermesAgent

final class FileSessionStoreTests: XCTestCase {
    func testMissingFileLoadsEmptySessions() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesAgentTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("sessions.json")
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = FileSessionStore(fileURL: fileURL)

        XCTAssertEqual(try store.loadSessions(), [])
    }

    func testRoundTripSessions() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesAgentTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("sessions.json")
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = FileSessionStore(fileURL: fileURL)
        let sessions = [
            StoredSession(id: "session_1", title: "Planning", messages: ["Hello", "Hi"]),
            StoredSession(id: "session_2", title: "Coding", messages: ["Run tests"])
        ]

        try store.saveSessions(sessions)

        XCTAssertEqual(try store.loadSessions(), sessions)
    }
}
