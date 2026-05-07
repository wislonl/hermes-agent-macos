import Foundation

struct StoredSession: Codable, Equatable {
    let id: String
    var title: String
    var messages: [String]
}

protocol SessionStore {
    func loadSessions() throws -> [StoredSession]
    func saveSessions(_ sessions: [StoredSession]) throws
}
