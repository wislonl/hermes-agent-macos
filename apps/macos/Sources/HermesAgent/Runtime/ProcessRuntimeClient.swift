import Foundation

final class ProcessRuntimeClient: RuntimeClient {
    private let runtimeURL: URL
    private(set) var lastEncodedRequestData: Data?

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
        lastEncodedRequestData = try JSONEncoder().encode(request)

        return RuntimeHandshakeResult(
            protocolVersion: "0.1.0",
            runtime: RuntimeInfo(name: runtimeURL.lastPathComponent, version: "0.1.0"),
            capabilities: ["runs", "tools", "approvals"]
        )
    }

    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        workspacePath: String
    ) async throws -> RunCreateResult {
        let request = JsonRpcRequest(
            id: "req_create_run",
            method: "run.create",
            params: RunCreateParams(
                sessionId: sessionId,
                agentProfileId: agentProfileId,
                input: RunInput(type: "text", text: input),
                workspace: Workspace(path: workspacePath)
            )
        )
        lastEncodedRequestData = try JSONEncoder().encode(request)

        return RunCreateResult(runId: "run_mock", status: "running")
    }
}
