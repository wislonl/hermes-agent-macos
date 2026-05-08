import Testing
import Foundation
@testable import HermesAgentCore

/// Tests for the ACP JSON-RPC wire schema decoding — the boundary between Hermes
/// process output and app state. Malformed JSON must never crash the app.
@Suite("ACPSchema")
struct ACPSchemaTests {

    // MARK: - ACPSessionUpdate decoding

    @Test("decodes agent_message_chunk")
    func decodesAgentMessageChunk() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"hello"}}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .agentMessageChunk(let text) = notif.update {
            #expect(text == "hello")
        } else {
            Issue.record("expected agentMessageChunk, got \(notif.update)")
        }
    }

    @Test("decodes agent_thought_chunk")
    func decodesAgentThoughtChunk() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"thinking…"}}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .agentThoughtChunk(let text) = notif.update {
            #expect(text == "thinking…")
        } else {
            Issue.record("expected agentThoughtChunk")
        }
    }

    @Test("decodes tool_call")
    func decodesToolCall() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"tool_call","toolCallId":"tc1","title":"Run tests","status":"in_progress","kind":"bash"}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .toolCall(let id, let title, let status, let kind) = notif.update {
            #expect(id == "tc1")
            #expect(title == "Run tests")
            #expect(status == "in_progress")
            #expect(kind == "bash")
        } else {
            Issue.record("expected toolCall")
        }
    }

    @Test("decodes tool_call_update")
    func decodesToolCallUpdate() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"tool_call_update","toolCallId":"tc1","title":"Done","status":"completed","content":{"type":"text","text":"output"}}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .toolCallUpdate(let id, let title, let status, let content) = notif.update {
            #expect(id == "tc1")
            #expect(title == "Done")
            #expect(status == "completed")
            #expect(content == "output")
        } else {
            Issue.record("expected toolCallUpdate")
        }
    }

    @Test("decodes available_commands_update")
    func decodesAvailableCommandsUpdate() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"available_commands_update","availableCommands":[{"name":"/help"},{"name":"/clear"}]}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .availableCommands(let names) = notif.update {
            #expect(names == ["/help", "/clear"])
        } else {
            Issue.record("expected availableCommands")
        }
    }

    @Test("unknown sessionUpdate kind produces .unknown case, no crash")
    func unknownKindProducesUnknownCase() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"future_kind_v99","someField":"ignored"}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .unknown(let kind) = notif.update {
            #expect(kind == "future_kind_v99")
        } else {
            Issue.record("expected unknown case")
        }
    }

    @Test("agent_message_chunk with missing content falls back to empty string")
    func missingContentFallsBack() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"agent_message_chunk"}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .agentMessageChunk(let text) = notif.update {
            #expect(text == "")
        } else {
            Issue.record("expected agentMessageChunk with empty text")
        }
    }

    @Test("tool_call with missing optional fields uses safe defaults")
    func toolCallMissingFields() throws {
        let json = """
        {"sessionId":"s1","sessionUpdate":"tool_call"}
        """
        let notif = try decode(ACPSessionUpdateNotification.self, from: json)
        if case .toolCall(let id, let title, let status, _) = notif.update {
            #expect(id == "")
            #expect(title == "Tool call")
            #expect(status == "pending")
        } else {
            Issue.record("expected toolCall with defaults")
        }
    }

    // MARK: - ACPInitializeResult

    @Test("decodes minimal initialize result")
    func decodesMinimalInitResult() throws {
        let json = """
        {"protocolVersion":1}
        """
        let result = try decode(ACPInitializeResult.self, from: json)
        #expect(result.protocolVersion == 1)
        #expect(result.agentInfo == nil)
    }

    @Test("decodes full initialize result with agent info")
    func decodesFullInitResult() throws {
        let json = """
        {"protocolVersion":1,"agentInfo":{"name":"hermes-agent","version":"0.9.1"}}
        """
        let result = try decode(ACPInitializeResult.self, from: json)
        #expect(result.agentInfo?.name == "hermes-agent")
        #expect(result.agentInfo?.version == "0.9.1")
    }

    // MARK: - ACPSessionModelState

    @Test("decodes model state with available models")
    func decodesModelState() throws {
        let json = """
        {"availableModels":[{"modelId":"claude-sonnet-4-6","name":"Claude Sonnet","description":null}],"currentModelId":"claude-sonnet-4-6"}
        """
        let state = try decode(ACPSessionModelState.self, from: json)
        #expect(state.availableModels.count == 1)
        #expect(state.availableModels[0].modelId == "claude-sonnet-4-6")
        #expect(state.currentModelId == "claude-sonnet-4-6")
    }

    // MARK: - ACPRequestPermissionParams

    @Test("decodes permission request with options")
    func decodesPermissionRequest() throws {
        let json = """
        {
          "sessionId": "s1",
          "toolCall": {"toolCallId": "tc1", "title": "Read file", "kind": "fs_read", "status": "pending"},
          "options": [
            {"optionId": "allow", "name": "Allow", "kind": "approve"},
            {"optionId": "deny",  "name": "Deny",  "kind": "reject"}
          ]
        }
        """
        let req = try decode(ACPRequestPermissionParams.self, from: json)
        #expect(req.toolCall.toolCallId == "tc1")
        #expect(req.options.count == 2)
        #expect(req.options[0].optionId == "allow")
        #expect(req.options[1].kind == "reject")
    }
}

// MARK: - Helper

private func decode<T: Decodable>(_ type: T.Type, from jsonString: String) throws -> T {
    let data = Data(jsonString.utf8)
    return try JSONDecoder().decode(type, from: data)
}
