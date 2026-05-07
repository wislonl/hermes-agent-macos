import Foundation

enum RuntimeEvent: Equatable {
    case messageDelta(runId: String, delta: String)
    case toolRequested(runId: String, toolCallId: String, tool: String, summary: String)
    case approvalRequired(runId: String, approvalId: String, toolCallId: String, command: String)
    case runCompleted(runId: String, status: String)
}
