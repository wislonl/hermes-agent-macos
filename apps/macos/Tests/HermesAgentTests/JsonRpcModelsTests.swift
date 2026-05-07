import XCTest
@testable import HermesAgent

final class JsonRpcModelsTests: XCTestCase {
    func testHandshakeRequestEncodesJsonRpcEnvelope() throws {
        let request = JsonRpcRequest(
            id: "req_1",
            method: "runtime.handshake",
            params: RuntimeHandshakeParams(
                protocolVersion: "0.1.0",
                client: RuntimeClientInfo(name: "Hermes.app", version: "0.1.0")
            )
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let params = try XCTUnwrap(object["params"] as? [String: Any])
        let client = try XCTUnwrap(params["client"] as? [String: Any])

        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["id"] as? String, "req_1")
        XCTAssertEqual(object["method"] as? String, "runtime.handshake")
        XCTAssertEqual(params["protocolVersion"] as? String, "0.1.0")
        XCTAssertEqual(client["name"] as? String, "Hermes.app")
        XCTAssertEqual(client["version"] as? String, "0.1.0")
    }

    func testSuccessResponseDecodesStringID() throws {
        let response = try decodeRunCreateResponse(
            """
            {"jsonrpc":"2.0","id":"req_2","result":{"runId":"run_123","status":"running"}}
            """
        )

        XCTAssertEqual(response.id, .string("req_2"))
        XCTAssertEqual(response.result, RunCreateResult(runId: "run_123", status: "running"))
        XCTAssertNil(response.error)
    }

    func testResponseWithWrongJsonRpcVersionFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"1.0","id":"req_2","result":{"runId":"run_123","status":"running"}}
                """
            )
        )
    }

    func testResponseWithExtraTopLevelKeyFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","id":"req_2","result":{"runId":"run_123","status":"running"},"extra":true}
                """
            )
        )
    }

    func testErrorResponseDecodesNullID() throws {
        let response = try decodeRunCreateResponse(
            """
            {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
            """
        )

        XCTAssertEqual(response.id, .null)
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, JsonRpcError(code: -32700, message: "Parse error", data: nil))
    }

    func testResponseDecodesIntegerID() throws {
        let response = try decodeRunCreateResponse(
            """
            {"jsonrpc":"2.0","id":42,"result":{"runId":"run_123","status":"running"}}
            """
        )

        XCTAssertEqual(response.id, .integer(42))
    }

    func testResponseMissingIDFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","result":{"runId":"run_123","status":"running"}}
                """
            )
        )
    }

    func testResponseWithBothResultAndErrorFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","id":"req_2","result":{"runId":"run_123","status":"running"},"error":{"code":-32603,"message":"Internal error"}}
                """
            )
        )
    }

    func testResponseWithNeitherResultNorErrorFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","id":"req_2"}
                """
            )
        )
    }

    func testSuccessResponseWithNullIDFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","id":null,"result":{"runId":"run_123","status":"running"}}
                """
            )
        )
    }

    func testRequestWithNullIDFailsEncoding() {
        let request = JsonRpcRequest(
            id: .null,
            method: "run.create",
            params: RunCreateParams(
                sessionId: "session_123",
                agentProfileId: "agent_hermes",
                input: RunInput(type: "text", text: "Summarize this repository."),
                workspace: Workspace(path: "/Users/example/project")
            )
        )

        XCTAssertThrowsError(try JSONEncoder().encode(request))
    }

    func testRunCreateResultWithNonRunningStatusFailsDecoding() {
        XCTAssertThrowsError(
            try decodeRunCreateResponse(
                """
                {"jsonrpc":"2.0","id":"req_2","result":{"runId":"run_123","status":"completed"}}
                """
            )
        )
    }

    private func decodeRunCreateResponse(_ json: String) throws -> JsonRpcResponse<RunCreateResult> {
        try JSONDecoder().decode(JsonRpcResponse<RunCreateResult>.self, from: Data(json.utf8))
    }
}
