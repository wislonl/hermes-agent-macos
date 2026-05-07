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
}
