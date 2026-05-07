import XCTest
@testable import HermesAgent

final class RuntimeClientTests: XCTestCase {
    func testProcessRuntimeClientCreateRunStartsProcessAndDecodesResponseEvents() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesRuntimeClientTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let requestURL = tempDirectory.appendingPathComponent("request.json")
        let runtimeURL = tempDirectory.appendingPathComponent("fake-runtime")
        let script = """
        #!/bin/sh
        IFS= read -r line
        printf '%s\\n' "$line" > "\(requestURL.path)"
        printf '%s\\n' '{"jsonrpc":"2.0","id":"req_create_run","result":{"runId":"run_from_process","status":"running"}}'
        printf '%s\\n' '{"event":"message.delta","runId":"run_from_process","delta":"Echo from runtime"}'
        printf '%s\\n' '{"event":"run.completed","runId":"run_from_process","status":"completed"}'
        """
        try script.write(to: runtimeURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeURL.path)

        let client = ProcessRuntimeClient(runtimeURL: runtimeURL)

        let run = try await client.createRun(
            sessionId: "session_123",
            agentProfileId: "agent_hermes",
            input: "Summarize this repository.",
            history: [
                RunHistoryMessage(role: "user", content: "Summarize this repository.")
            ],
            workspacePath: "/Users/example/project"
        )

        XCTAssertEqual(run.result, RunCreateResult(runId: "run_from_process", status: "running"))
        XCTAssertEqual(run.events, [
            .messageDelta(runId: "run_from_process", delta: "Echo from runtime"),
            .runCompleted(runId: "run_from_process", status: "completed")
        ])

        let requestData = try Data(contentsOf: requestURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["method"] as? String, "run.create")
    }

    func testProcessRuntimeClientHandshakeReturnsRuntimeIdentityAndCapabilities() async throws {
        let runtimeURL = try makeFakeRuntime(
            response: #"{"jsonrpc":"2.0","id":"req_handshake","result":{"protocolVersion":"0.1.0","runtime":{"name":"hermes-runtime-test","version":"0.1.0"},"capabilities":["runs","tools","approvals"]}}"#
        )
        let client = ProcessRuntimeClient(runtimeURL: runtimeURL)

        let result = try await client.handshake()

        XCTAssertEqual(result.protocolVersion, "0.1.0")
        XCTAssertEqual(result.runtime.name, "hermes-runtime-test")
        XCTAssertEqual(result.runtime.version, "0.1.0")
        XCTAssertEqual(result.capabilities, ["runs", "tools", "approvals"])
    }

    func testProcessRuntimeClientTestProviderReturnsProviderStatus() async throws {
        let runtimeURL = try makeFakeRuntime(
            response: #"{"jsonrpc":"2.0","id":"req_provider_test","result":{"status":"ok","provider":"Echo","model":"echo"}}"#
        )
        let client = ProcessRuntimeClient(runtimeURL: runtimeURL)

        let result = try await client.testProvider()

        XCTAssertEqual(result, ProviderTestResult(status: "ok", provider: "Echo", model: "echo"))
        let data = try XCTUnwrap(client.lastEncodedRequestData)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["id"] as? String, "req_provider_test")
        XCTAssertEqual(object["method"] as? String, "provider.test")
    }

    func testProviderTestRequestEncodesSchemaValidParams() throws {
        let request = JsonRpcRequest(
            id: "req_provider_test",
            method: "provider.test",
            params: ProviderTestParams()
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["id"] as? String, "req_provider_test")
        XCTAssertEqual(object["method"] as? String, "provider.test")
        XCTAssertEqual((object["params"] as? [String: Any])?.isEmpty, true)
    }

    func testProcessRuntimeClientCreateRunReturnsDeterministicResult() async throws {
        let runtimeURL = try makeFakeRuntime(
            response: #"{"jsonrpc":"2.0","id":"req_create_run","result":{"runId":"run_mock","status":"running"}}"#
        )
        let client = ProcessRuntimeClient(runtimeURL: runtimeURL)

        let result = try await client.createRun(
            sessionId: "session_123",
            agentProfileId: "agent_hermes",
            input: "Summarize this repository.",
            history: [
                RunHistoryMessage(role: "user", content: "Summarize this repository.")
            ],
            workspacePath: "/Users/example/project"
        )

        XCTAssertEqual(result.result, RunCreateResult(runId: "run_mock", status: "running"))

        let data = try XCTUnwrap(client.lastEncodedRequestData)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let params = try XCTUnwrap(object["params"] as? [String: Any])
        let input = try XCTUnwrap(params["input"] as? [String: Any])
        let workspace = try XCTUnwrap(params["workspace"] as? [String: Any])

        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["id"] as? String, "req_create_run")
        XCTAssertEqual(object["method"] as? String, "run.create")
        XCTAssertEqual(params["sessionId"] as? String, "session_123")
        XCTAssertEqual(params["agentProfileId"] as? String, "agent_hermes")
        XCTAssertEqual(input["type"] as? String, "text")
        XCTAssertEqual(input["text"] as? String, "Summarize this repository.")
        let history = try XCTUnwrap(params["history"] as? [[String: Any]])
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?["role"] as? String, "user")
        XCTAssertEqual(history.first?["content"] as? String, "Summarize this repository.")
        XCTAssertEqual(workspace["path"] as? String, "/Users/example/project")
    }

    func testRunCreateRequestEncodesSchemaValidParams() throws {
        let request = JsonRpcRequest(
            id: "req_2",
            method: "run.create",
            params: RunCreateParams(
                sessionId: "session_123",
                agentProfileId: "agent_hermes",
                input: RunInput(type: "text", text: "Summarize this repository."),
                history: [
                    RunHistoryMessage(role: "assistant", content: "Previous answer"),
                    RunHistoryMessage(role: "user", content: "Summarize this repository.")
                ],
                workspace: Workspace(path: "/Users/example/project")
            )
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let params = try XCTUnwrap(object["params"] as? [String: Any])
        let input = try XCTUnwrap(params["input"] as? [String: Any])
        let workspace = try XCTUnwrap(params["workspace"] as? [String: Any])

        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["id"] as? String, "req_2")
        XCTAssertEqual(object["method"] as? String, "run.create")
        XCTAssertEqual(params["sessionId"] as? String, "session_123")
        XCTAssertEqual(params["agentProfileId"] as? String, "agent_hermes")
        XCTAssertEqual(input["type"] as? String, "text")
        XCTAssertEqual(input["text"] as? String, "Summarize this repository.")
        let history = try XCTUnwrap(params["history"] as? [[String: Any]])
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0]["role"] as? String, "assistant")
        XCTAssertEqual(history[0]["content"] as? String, "Previous answer")
        XCTAssertEqual(history[1]["role"] as? String, "user")
        XCTAssertEqual(history[1]["content"] as? String, "Summarize this repository.")
        XCTAssertEqual(workspace["path"] as? String, "/Users/example/project")
    }
}

private func makeFakeRuntime(response: String) throws -> URL {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HermesRuntimeClientTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    let runtimeURL = tempDirectory.appendingPathComponent("fake-runtime")
    let script = """
    #!/bin/sh
    IFS= read -r line
    printf '%s\\n' '\(response)'
    """
    try script.write(to: runtimeURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeURL.path)
    return runtimeURL
}
