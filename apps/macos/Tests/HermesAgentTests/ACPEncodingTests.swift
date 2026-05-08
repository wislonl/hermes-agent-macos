import Testing
import Foundation
@testable import HermesAgentCore

/// Tests that outbound ACP messages encode with the correct field names and structure.
@Suite("ACPEncoding")
struct ACPEncodingTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    @Test("ACPInitializeParams encodes protocolVersion and clientCapabilities")
    func encodeInitializeParams() throws {
        let params = ACPInitializeParams(
            protocolVersion: 1,
            clientCapabilities: ACPClientCapabilities()
        )
        let obj = try encode(params)
        #expect(obj["protocolVersion"] as? Int == 1)
        #expect(obj["clientCapabilities"] != nil)
    }

    @Test("ACPNewSessionParams encodes cwd and mcpServers")
    func encodeNewSessionParams() throws {
        let params = ACPNewSessionParams(cwd: "/tmp/project", mcpServers: [])
        let obj = try encode(params)
        #expect(obj["cwd"] as? String == "/tmp/project")
        #expect((obj["mcpServers"] as? [Any])?.isEmpty == true)
    }

    @Test("ACPPromptParams encodes sessionId and prompt array")
    func encodePromptParams() throws {
        let params = ACPPromptParams(
            sessionId: "sess-1",
            prompt: [.text("hello")]
        )
        let obj = try encode(params)
        #expect(obj["sessionId"] as? String == "sess-1")
        let blocks = obj["prompt"] as? [[String: Any]]
        #expect(blocks?.count == 1)
        #expect(blocks?.first?["type"] as? String == "text")
        #expect(blocks?.first?["text"] as? String == "hello")
    }

    @Test("ACPContentBlock.text factory sets type to 'text'")
    func contentBlockTextType() throws {
        let block = ACPContentBlock.text("world")
        let obj = try encode(block)
        #expect(obj["type"] as? String == "text")
        #expect(obj["text"] as? String == "world")
    }

    @Test("ACPSetSessionModelParams encodes sessionId and modelId")
    func encodeSetSessionModelParams() throws {
        let params = ACPSetSessionModelParams(sessionId: "s1", modelId: "claude-3")
        let obj = try encode(params)
        #expect(obj["sessionId"] as? String == "s1")
        #expect(obj["modelId"] as? String == "claude-3")
    }

    @Test("ACPCancelParams encodes sessionId")
    func encodeCancelParams() throws {
        let params = ACPCancelParams(sessionId: "sess-99")
        let obj = try encode(params)
        #expect(obj["sessionId"] as? String == "sess-99")
    }

    @Test("ACPListSessionsParams with nil fields encodes null values")
    func encodeListSessionsNilCursor() throws {
        let params = ACPListSessionsParams(cwd: nil, cursor: nil)
        let data = try encoder.encode(params)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["cwd"] is NSNull || obj["cwd"] == nil)
    }

    @Test("ACPFsCapabilities defaults are false")
    func fsCapsDefaults() throws {
        let caps = ACPFsCapabilities()
        let obj = try encode(caps)
        #expect(obj["readTextFile"] as? Bool == false)
        #expect(obj["writeTextFile"] as? Bool == false)
    }
}
