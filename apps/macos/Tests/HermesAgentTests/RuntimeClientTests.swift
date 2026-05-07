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
}
