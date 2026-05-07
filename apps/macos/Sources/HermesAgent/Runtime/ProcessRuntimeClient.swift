import Foundation

final class ProcessRuntimeClient: RuntimeClient {
    private let runtimeURL: URL

    init(runtimeURL: URL) {
        self.runtimeURL = runtimeURL
    }

    func handshake() async throws -> RuntimeHandshakeResult {
        let request = JsonRpcRequest(
            id: "req_handshake",
            method: "runtime.handshake",
            params: RuntimeHandshakeParams(
                protocolVersion: "0.1.0",
                client: RuntimeClientInfo(name: "Hermes.app", version: "0.1.0")
            )
        )
        _ = try JSONEncoder().encode(request)

        return RuntimeHandshakeResult(
            protocolVersion: "0.1.0",
            runtime: RuntimeInfo(name: runtimeURL.lastPathComponent, version: "0.1.0"),
            capabilities: ["runs", "tools", "approvals"]
        )
    }

    func createRun(input: String, workspacePath: String?) async throws {
        _ = input
        _ = workspacePath
    }
}
