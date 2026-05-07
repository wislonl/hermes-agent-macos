import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Author: Equatable {
        case user
        case agent
        case system
    }

    let id: UUID
    let author: Author
    var text: String
}

struct ToolCallView: Identifiable, Equatable {
    enum Status: Equatable {
        case pending
        case running
        case completed
        case failed
    }

    let id: String
    var title: String
    var detail: String
    var status: Status
}

struct ApprovalPrompt: Identifiable, Equatable {
    struct Option: Identifiable, Equatable {
        let id: String
        let name: String
        let kind: String
    }

    let id: String
    let toolCall: String
    let summary: String
    let options: [Option]
}

struct SessionSummary: Identifiable, Equatable {
    let id: String
    var title: String
    var cwd: String
    var updatedAt: String?
}

struct AvailableModel: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
}
