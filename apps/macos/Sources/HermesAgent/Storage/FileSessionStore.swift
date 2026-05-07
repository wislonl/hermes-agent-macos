import Foundation

struct FileSessionStore: SessionStore {
    let fileURL: URL

    func loadSessions() throws -> [StoredSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([StoredSession].self, from: data)
    }

    func saveSessions(_ sessions: [StoredSession]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }
}
