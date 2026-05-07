import Foundation

protocol RuntimeClient {
    func handshake() async throws -> RuntimeHandshakeResult
    func createRun(input: String, workspacePath: String?) async throws
}
