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

    func submitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        draft = ""
    }
}
