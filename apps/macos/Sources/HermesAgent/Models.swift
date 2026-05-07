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

    var displayTitle: String {
        var s = title
        // If there's a closing </think>, keep only what comes after it.
        if let closeRange = s.range(of: "</think>", options: .caseInsensitive) {
            s = String(s[closeRange.upperBound...])
        } else if let openRange = s.range(of: "<think>", options: .caseInsensitive) {
            // Unclosed <think> block — drop everything from it onward.
            s = String(s[s.startIndex..<openRange.lowerBound])
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Session \(id.prefix(8))" : s
    }

    var displayCwd: String {
        let home = NSHomeDirectory()
        if cwd == "/" { return "~" }
        return cwd.hasPrefix(home) ? "~" + cwd.dropFirst(home.count) : cwd
    }
}

struct AvailableModel: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
}
