import Foundation

enum ProcessRuntimeClientError: Error, Equatable {
    case emptyResponse
    case invalidUTF8Output
    case runtimeError(code: Int, message: String)
    case missingResult
    case processFailed(status: Int32, stderr: String)
}

extension ProcessRuntimeClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Runtime exited without returning a JSON-RPC response."
        case .invalidUTF8Output:
            return "Runtime returned output that is not valid UTF-8."
        case .runtimeError(_, let message):
            return message
        case .missingResult:
            return "Runtime response did not include a result."
        case .processFailed(let status, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "Runtime process failed with status \(status)."
            }
            return "Runtime process failed with status \(status): \(detail)"
        }
    }
}

final class ProcessRuntimeClient: RuntimeClient {
    private let runtimeURL: URL
    private let extraEnvironment: [String: String]
    private(set) var lastEncodedRequestData: Data?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(runtimeURL: URL, extraEnvironment: [String: String] = [:]) {
        self.runtimeURL = runtimeURL
        self.extraEnvironment = extraEnvironment
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

        let response: RuntimeProcessResponse<RuntimeHandshakeResult> = try await send(request)
        return response.result
    }

    func testProvider() async throws -> ProviderTestResult {
        let request = JsonRpcRequest(
            id: "req_provider_test",
            method: "provider.test",
            params: ProviderTestParams()
        )

        let response: RuntimeProcessResponse<ProviderTestResult> = try await send(request)
        return response.result
    }

    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        history: [RunHistoryMessage],
        workspacePath: String
    ) async throws -> RuntimeRun {
        let request = JsonRpcRequest(
            id: "req_create_run",
            method: "run.create",
            params: RunCreateParams(
                sessionId: sessionId,
                agentProfileId: agentProfileId,
                input: RunInput(type: "text", text: input),
                history: history,
                workspace: Workspace(path: workspacePath)
            )
        )

        let response: RuntimeProcessResponse<RunCreateResult> = try await send(request)
        return RuntimeRun(result: response.result, events: response.events)
    }

    private func send<Params: Encodable, Result: Decodable>(
        _ request: JsonRpcRequest<Params>
    ) async throws -> RuntimeProcessResponse<Result> {
        let requestData = try encoder.encode(request)
        lastEncodedRequestData = requestData

        return try await Task.detached { [runtimeURL, extraEnvironment, decoder] in
            let process = Process()
            process.executableURL = runtimeURL
            if !extraEnvironment.isEmpty {
                process.environment = ProcessInfo.processInfo.environment.merging(extraEnvironment) { _, new in new }
            }

            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            stdin.fileHandleForWriting.write(requestData)
            stdin.fileHandleForWriting.write(Data([0x0A]))
            try stdin.fileHandleForWriting.close()

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let stderrText = String(data: errorData, encoding: .utf8) ?? ""
                throw ProcessRuntimeClientError.processFailed(
                    status: process.terminationStatus,
                    stderr: stderrText
                )
            }

            guard let output = String(data: outputData, encoding: .utf8) else {
                throw ProcessRuntimeClientError.invalidUTF8Output
            }

            let lines = output
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard let responseLine = lines.first else {
                throw ProcessRuntimeClientError.emptyResponse
            }

            let responseData = Data(responseLine.utf8)
            let response = try decoder.decode(JsonRpcResponse<Result>.self, from: responseData)
            if let error = response.error {
                throw ProcessRuntimeClientError.runtimeError(
                    code: error.code,
                    message: error.message
                )
            }
            guard let result = response.result else {
                throw ProcessRuntimeClientError.missingResult
            }

            let events = try lines.dropFirst().map { line in
                try decoder.decode(RuntimeEvent.self, from: Data(line.utf8))
            }
            return RuntimeProcessResponse(result: result, events: events)
        }.value
    }
}

private struct RuntimeProcessResponse<Result> {
    let result: Result
    let events: [RuntimeEvent]
}
