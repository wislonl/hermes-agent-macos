import Foundation

struct AgentProfile: Identifiable, Equatable {
    let id: String
    var name: String
    var role: String
}

struct ChatMessage: Identifiable, Equatable {
    enum Author {
        case user
        case assistant
        case system
    }

    let id: UUID
    var author: Author
    var text: String
}

struct ToolCall: Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var requiresApproval: Bool
    var approvalId: String?
}
