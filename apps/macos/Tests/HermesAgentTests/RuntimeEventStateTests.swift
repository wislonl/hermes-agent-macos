import XCTest
@testable import HermesAgent

final class RuntimeEventStateTests: XCTestCase {
    func testApprovalRequiredAddsApprovalToolCall() {
        let state = AppState()

        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "swift test --package-path apps/macos"
        ))

        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.id, "tool_1")
        XCTAssertEqual(state.toolCalls.last?.title, "Approval required")
        XCTAssertEqual(state.toolCalls.last?.detail, "swift test --package-path apps/macos")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, true)
        XCTAssertEqual(state.toolCalls.last?.approvalId, "approval_1")
        XCTAssertEqual(state.approvals, [
            ApprovalRequest(
                id: "approval_1",
                command: "swift test --package-path apps/macos",
                decision: nil
            )
        ])
    }

    func testApprovalRequiredUpdatesExistingToolCall() {
        let state = AppState()

        state.apply(event: .toolRequested(
            runId: "run_1",
            toolCallId: "tool_1",
            tool: "shell",
            summary: "Preview shell command"
        ))
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "pwd"
        ))

        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.id, "tool_1")
        XCTAssertEqual(state.toolCalls.last?.title, "shell")
        XCTAssertEqual(state.toolCalls.last?.detail, "pwd")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, true)
        XCTAssertEqual(state.toolCalls.last?.approvalId, "approval_1")
    }

    func testDuplicateApprovalRequiredUpdatesExistingApprovalRequest() {
        let state = AppState()

        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "pwd"
        ))
        state.resolveApproval(id: "approval_1", decision: .denied)
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "ls"
        ))

        XCTAssertEqual(state.approvals, [
            ApprovalRequest(id: "approval_1", command: "ls", decision: .denied)
        ])
        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.detail, "ls")
    }

    func testToolRequestedDoesNotDuplicateExistingApprovalToolCall() {
        let state = AppState()

        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "pwd"
        ))
        state.apply(event: .toolRequested(
            runId: "run_1",
            toolCallId: "tool_1",
            tool: "shell",
            summary: "Preview shell command"
        ))

        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.id, "tool_1")
        XCTAssertEqual(state.toolCalls.last?.title, "shell")
        XCTAssertEqual(state.toolCalls.last?.detail, "pwd")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, true)
        XCTAssertEqual(state.toolCalls.last?.approvalId, "approval_1")
    }

    func testToolRequestedAddsNonApprovalToolCall() {
        let state = AppState()

        state.apply(event: .toolRequested(
            runId: "run_1",
            toolCallId: "tool_1",
            tool: "shell",
            summary: "List project files"
        ))

        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.id, "tool_1")
        XCTAssertEqual(state.toolCalls.last?.title, "shell")
        XCTAssertEqual(state.toolCalls.last?.detail, "List project files")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, false)
        XCTAssertNil(state.toolCalls.last?.approvalId)
    }

    func testMessageDeltaAddsAssistantMessage() {
        let state = AppState()

        state.apply(event: .messageDelta(runId: "run_1", delta: "Runtime response"))

        XCTAssertEqual(state.messages.last?.author, .assistant)
        XCTAssertEqual(state.messages.last?.text, "Runtime response")
    }

    func testSubmitDraftAppendsUserMessageAndMockAssistantEvent() {
        let state = AppState()
        state.draft = "Hello Hermes"

        state.submitDraft()

        XCTAssertEqual(state.messages.suffix(2).map(\.author), [.user, .assistant])
        XCTAssertEqual(state.messages.suffix(2).map(\.text), [
            "Hello Hermes",
            "Hermes is connected to the workbench."
        ])
        XCTAssertEqual(state.draft, "")
    }

    func testSubmitDraftWithShellPromptCreatesApprovalRequest() {
        let state = AppState()
        state.draft = "/shell pwd && ls"

        state.submitDraft()

        XCTAssertEqual(state.messages.last?.author, .user)
        XCTAssertEqual(state.messages.last?.text, "/shell pwd && ls")
        XCTAssertEqual(state.toolCalls.count, 1)
        XCTAssertEqual(state.toolCalls.last?.title, "shell")
        XCTAssertEqual(state.toolCalls.last?.detail, "pwd && ls")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, true)
        XCTAssertEqual(state.approvals.count, 1)
        XCTAssertEqual(state.approvals.last?.command, "pwd && ls")
        XCTAssertNil(state.approvals.last?.decision)
        XCTAssertEqual(state.draft, "")
    }

    func testSubmitDraftWithMultipleShellPromptsCreatesDistinctApprovalRequests() {
        let state = AppState()

        state.draft = "/shell pwd"
        state.submitDraft()
        state.draft = "/shell ls"
        state.submitDraft()

        XCTAssertEqual(state.toolCalls.count, 2)
        XCTAssertEqual(state.approvals.count, 2)
        XCTAssertNotEqual(state.toolCalls[0].id, state.toolCalls[1].id)
        XCTAssertNotEqual(state.approvals[0].id, state.approvals[1].id)
        XCTAssertEqual(state.approvals.map(\.command), ["pwd", "ls"])
    }

    func testSubmitDraftWithShellMentionLaterDoesNotCreateApprovalRequest() {
        let state = AppState()
        state.draft = "Explain why /shell needs approval."

        state.submitDraft()

        XCTAssertTrue(state.toolCalls.isEmpty)
        XCTAssertTrue(state.approvals.isEmpty)
        XCTAssertEqual(state.messages.last?.author, .assistant)
    }
}
