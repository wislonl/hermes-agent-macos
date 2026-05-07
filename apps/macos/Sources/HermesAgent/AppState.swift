import Foundation
import Observation

@Observable
final class AppState {
    var agents: [AgentProfile] = [
        AgentProfile(id: "agent_hermes", name: "Hermes", role: "General desktop agent"),
        AgentProfile(id: "agent_research", name: "Research", role: "Research profile"),
        AgentProfile(id: "agent_coding", name: "Coding", role: "Coding profile")
    ]
    var selectedAgentId = "agent_hermes"
    var messages: [ChatMessage] = [
        ChatMessage(id: UUID(), author: .assistant, text: "Hermes is ready.")
    ]
    var toolCalls: [ToolCall] = []
    var draft = ""

    func apply(event: RuntimeEvent) {
        switch event {
        case .messageDelta(_, let delta):
            messages.append(ChatMessage(id: UUID(), author: .assistant, text: delta))
        case .toolRequested(_, let toolCallId, let tool, let summary):
            toolCalls.append(ToolCall(id: toolCallId, title: tool, detail: summary, requiresApproval: false))
        case .approvalRequired(_, let approvalId, _, let command):
            toolCalls.append(ToolCall(id: approvalId, title: "Approval required", detail: command, requiresApproval: true))
        case .runCompleted:
            break
        }
    }

    func submitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        apply(event: .messageDelta(runId: "run_preview", delta: "Hermes is connected to the workbench."))
        draft = ""
    }
}
