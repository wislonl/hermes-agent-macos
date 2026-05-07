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

    func testSubmitDraftAppendsUserMessageAndRuntimeAssistantEvent() async {
        let state = AppState(runtimeClient: StateRuntimeClient(eventsByInput: [
            "Hello Hermes": [.messageDelta(runId: "run_1", delta: "Hermes is connected to the workbench.")]
        ]))
        state.draft = "Hello Hermes"

        await state.submitDraft()

        XCTAssertEqual(state.messages.suffix(2).map(\.author), [.user, .assistant])
        XCTAssertEqual(state.messages.suffix(2).map(\.text), [
            "Hello Hermes",
            "Hermes is connected to the workbench."
        ])
        XCTAssertEqual(state.draft, "")
    }

    func testSubmitDraftWithShellPromptCreatesApprovalRequest() async {
        let state = AppState(runtimeClient: StateRuntimeClient(eventsByInput: [
            "/shell pwd && ls": [
                .toolRequested(
                    runId: "run_1",
                    toolCallId: "tool_shell_preview_run_1",
                    tool: "shell",
                    summary: "Preview shell command"
                ),
                .approvalRequired(
                    runId: "run_1",
                    approvalId: "approval_shell_preview_run_1",
                    toolCallId: "tool_shell_preview_run_1",
                    command: "pwd && ls"
                )
            ]
        ]))
        state.draft = "/shell pwd && ls"

        await state.submitDraft()

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

    func testSubmitDraftWithMultipleShellPromptsCreatesDistinctApprovalRequests() async {
        let state = AppState(runtimeClient: StateRuntimeClient(eventsByInput: [
            "/shell pwd": [
                .toolRequested(
                    runId: "run_1",
                    toolCallId: "tool_shell_preview_run_1",
                    tool: "shell",
                    summary: "Preview shell command"
                ),
                .approvalRequired(
                    runId: "run_1",
                    approvalId: "approval_shell_preview_run_1",
                    toolCallId: "tool_shell_preview_run_1",
                    command: "pwd"
                )
            ],
            "/shell ls": [
                .toolRequested(
                    runId: "run_2",
                    toolCallId: "tool_shell_preview_run_2",
                    tool: "shell",
                    summary: "Preview shell command"
                ),
                .approvalRequired(
                    runId: "run_2",
                    approvalId: "approval_shell_preview_run_2",
                    toolCallId: "tool_shell_preview_run_2",
                    command: "ls"
                )
            ]
        ]))

        state.draft = "/shell pwd"
        await state.submitDraft()
        state.draft = "/shell ls"
        await state.submitDraft()

        XCTAssertEqual(state.toolCalls.count, 2)
        XCTAssertEqual(state.approvals.count, 2)
        XCTAssertNotEqual(state.toolCalls[0].id, state.toolCalls[1].id)
        XCTAssertNotEqual(state.approvals[0].id, state.approvals[1].id)
        XCTAssertEqual(state.approvals.map(\.command), ["pwd", "ls"])
    }

    func testSubmitDraftWithShellMentionLaterDoesNotCreateApprovalRequest() async {
        let state = AppState(runtimeClient: StateRuntimeClient(eventsByInput: [
            "Explain why /shell needs approval.": [
                .messageDelta(runId: "run_1", delta: "Runtime response")
            ]
        ]))
        state.draft = "Explain why /shell needs approval."

        await state.submitDraft()

        XCTAssertTrue(state.toolCalls.isEmpty)
        XCTAssertTrue(state.approvals.isEmpty)
        XCTAssertEqual(state.messages.last?.author, .assistant)
    }
}

private final class StateRuntimeClient: RuntimeClient {
    private let eventsByInput: [String: [RuntimeEvent]]

    init(eventsByInput: [String: [RuntimeEvent]]) {
        self.eventsByInput = eventsByInput
    }

    func handshake() async throws -> RuntimeHandshakeResult {
        RuntimeHandshakeResult(
            protocolVersion: "0.1.0",
            runtime: RuntimeInfo(name: "state-test-runtime", version: "0.1.0"),
            capabilities: ["runs"]
        )
    }

    func testProvider() async throws -> ProviderTestResult {
        ProviderTestResult(status: "ok", provider: "Echo", model: "echo")
    }

    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        history: [RunHistoryMessage],
        workspacePath: String
    ) async throws -> RuntimeRun {
        RuntimeRun(
            result: RunCreateResult(runId: "run_1", status: "running"),
            events: eventsByInput[input, default: []]
        )
    }
}
