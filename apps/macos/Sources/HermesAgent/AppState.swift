import Foundation
import Observation

enum ApprovalDecision: Equatable {
    case approved
    case denied
}

struct ApprovalRequest: Identifiable, Equatable {
    let id: String
    let command: String
    var decision: ApprovalDecision?
}

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
    var approvals: [ApprovalRequest] = []
    var draft = ""

    func apply(event: RuntimeEvent) {
        switch event {
        case .messageDelta(_, let delta):
            messages.append(ChatMessage(id: UUID(), author: .assistant, text: delta))
        case .toolRequested(_, let toolCallId, let tool, let summary):
            if let index = toolCalls.firstIndex(where: { $0.id == toolCallId }) {
                toolCalls[index].title = tool
                if !toolCalls[index].requiresApproval {
                    toolCalls[index].detail = summary
                }
            } else {
                toolCalls.append(ToolCall(
                    id: toolCallId,
                    title: tool,
                    detail: summary,
                    requiresApproval: false,
                    approvalId: nil
                ))
            }
        case .approvalRequired(_, let approvalId, let toolCallId, let command):
            approvals.append(ApprovalRequest(id: approvalId, command: command, decision: nil))
            if let index = toolCalls.firstIndex(where: { $0.id == toolCallId }) {
                toolCalls[index].detail = command
                toolCalls[index].requiresApproval = true
                toolCalls[index].approvalId = approvalId
            } else {
                toolCalls.append(ToolCall(
                    id: toolCallId,
                    title: "Approval required",
                    detail: command,
                    requiresApproval: true,
                    approvalId: approvalId
                ))
            }
        case .runCompleted:
            break
        }
    }

    func resolveApproval(id: String, decision: ApprovalDecision) {
        guard let index = approvals.firstIndex(where: { $0.id == id }) else { return }
        approvals[index].decision = decision
    }

    func submitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        if let command = shellCommand(from: trimmed) {
            apply(event: .toolRequested(
                runId: "run_preview",
                toolCallId: "tool_shell_preview_run_preview",
                tool: "shell",
                summary: "Preview shell command"
            ))
            apply(event: .approvalRequired(
                runId: "run_preview",
                approvalId: "approval_shell_preview_run_preview",
                toolCallId: "tool_shell_preview_run_preview",
                command: command
            ))
        } else {
            apply(event: .messageDelta(runId: "run_preview", delta: "Hermes is connected to the workbench."))
        }
        draft = ""
    }

    private func shellCommand(from prompt: String) -> String? {
        if prompt == "/shell" {
            return "pwd && ls"
        }

        guard prompt.hasPrefix("/shell") else {
            return nil
        }

        let remaining = String(prompt.dropFirst("/shell".count))
        guard remaining.first?.isWhitespace == true
        else {
            return nil
        }

        let command = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? "pwd && ls" : command
    }
}
