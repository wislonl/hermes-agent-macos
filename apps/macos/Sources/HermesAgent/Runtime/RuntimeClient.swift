import Foundation

protocol RuntimeClient {
    func handshake() async throws -> RuntimeHandshakeResult
    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        workspacePath: String
    ) async throws -> RunCreateResult
}
