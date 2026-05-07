import Foundation

struct RuntimeRun: Equatable {
    let result: RunCreateResult
    let events: [RuntimeEvent]
}

protocol RuntimeClient {
    func handshake() async throws -> RuntimeHandshakeResult
    func testProvider() async throws -> ProviderTestResult
    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        history: [RunHistoryMessage],
        workspacePath: String
    ) async throws -> RuntimeRun
}
