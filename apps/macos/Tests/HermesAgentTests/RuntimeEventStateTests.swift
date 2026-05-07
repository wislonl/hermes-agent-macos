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
        XCTAssertEqual(state.approvals, [
            ApprovalRequest(
                id: "approval_shell_preview_run_preview",
                command: "pwd && ls",
                decision: nil
            )
        ])
        XCTAssertEqual(state.draft, "")
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
