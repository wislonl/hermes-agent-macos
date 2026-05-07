import XCTest
@testable import HermesAgent

final class RuntimeClientTests: XCTestCase {
    func testProcessRuntimeClientHandshakeReturnsRuntimeIdentityAndCapabilities() async throws {
        let client = ProcessRuntimeClient(
            runtimeURL: URL(fileURLWithPath: "/usr/local/bin/hermes-runtime-test")
        )

        let result = try await client.handshake()

        XCTAssertEqual(result.protocolVersion, "0.1.0")
        XCTAssertEqual(result.runtime.name, "hermes-runtime-test")
        XCTAssertEqual(result.runtime.version, "0.1.0")
        XCTAssertEqual(result.capabilities, ["runs", "tools", "approvals"])
    }

    func testProcessRuntimeClientCreateRunReturnsDeterministicResult() async throws {
        let client = ProcessRuntimeClient(
            runtimeURL: URL(fileURLWithPath: "/usr/local/bin/hermes-runtime-test")
        )

        let result = try await client.createRun(
            sessionId: "session_123",
            agentProfileId: "agent_hermes",
            input: "Summarize this repository.",
            workspacePath: "/Users/example/project"
        )

        XCTAssertEqual(result, RunCreateResult(runId: "run_mock", status: "running"))

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
        XCTAssertEqual(workspace["path"] as? String, "/Users/example/project")
    }
}
