import XCTest
@testable import HermesAgent

final class ApprovalDecisionTests: XCTestCase {
    func testDenyApprovalRecordsDecision() {
        let state = AppState()
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "rm -rf build"
        ))

        state.resolveApproval(id: "approval_1", decision: .denied)

        XCTAssertEqual(state.approvals.first?.decision, .denied)
    }

    func testApproveApprovalRecordsDecision() {
        let state = AppState()
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "swift test --package-path apps/macos"
        ))

        state.resolveApproval(id: "approval_1", decision: .approved)

        XCTAssertEqual(state.approvals.first?.decision, .approved)
    }

    func testUnknownApprovalIdDoesNotChangeApprovals() {
        let state = AppState()
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "pwd"
        ))

        state.resolveApproval(id: "missing", decision: .denied)

        XCTAssertEqual(state.approvals, [
            ApprovalRequest(id: "approval_1", command: "pwd", decision: nil)
        ])
    }
}
