import Foundation

// Subset of the Agent Client Protocol (ACP) wire schema needed by Hermes Agent.app.
// camelCase field names are how `hermes acp` serialises its messages.

enum ACPMethod {
    static let initialize = "initialize"
    static let authenticate = "authenticate"
    static let newSession = "session/new"
    static let loadSession = "session/load"
    static let resumeSession = "session/resume"
    static let listSessions = "session/list"
    static let cancel = "session/cancel"
    static let prompt = "session/prompt"
    static let setSessionModel = "session/set_model"
    static let sessionUpdate = "session/update"
    static let requestPermission = "session/request_permission"
}

struct ACPInitializeParams: Encodable {
    let protocolVersion: Int
    let clientCapabilities: ACPClientCapabilities
}

struct ACPClientCapabilities: Encodable {
    var fs: ACPFsCapabilities = ACPFsCapabilities()
}

struct ACPFsCapabilities: Encodable {
    var readTextFile: Bool = false
    var writeTextFile: Bool = false
}

struct ACPInitializeResult: Decodable {
    let protocolVersion: Int
    let agentInfo: ACPImplementation?
    let agentCapabilities: ACPAgentCapabilities?
    let authMethods: [ACPAuthMethod]?
}

struct ACPImplementation: Decodable {
    let name: String
    let version: String?
}

struct ACPAgentCapabilities: Decodable {
    let loadSession: Bool?
    let sessionCapabilities: ACPSessionCapabilities?
}

struct ACPSessionCapabilities: Decodable {
    let fork: ACPEmpty?
    let list: ACPEmpty?
    let resume: ACPEmpty?
}

struct ACPAuthMethod: Decodable {
    let id: String
    let name: String
    let description: String?
}

struct ACPEmpty: Codable {}

struct ACPNewSessionParams: Encodable {
    let cwd: String
    let mcpServers: [ACPEmpty]
}

struct ACPNewSessionResult: Decodable {
    let sessionId: String
    let models: ACPSessionModelState?
}

struct ACPLoadSessionParams: Encodable {
    let cwd: String
    let sessionId: String
    let mcpServers: [ACPEmpty]
}

struct ACPLoadSessionResult: Decodable {
    let models: ACPSessionModelState?
}

struct ACPListSessionsParams: Encodable {
    let cwd: String?
    let cursor: String?
}

struct ACPListSessionsResult: Decodable {
    let sessions: [ACPSessionInfo]
    let nextCursor: String?
}

struct ACPSessionInfo: Decodable {
    let sessionId: String
    let cwd: String
    let title: String?
    let updatedAt: String?
}

struct ACPSessionModelState: Decodable {
    let availableModels: [ACPModelInfo]
    let currentModelId: String?
}

struct ACPModelInfo: Decodable {
    let modelId: String
    let name: String
    let description: String?
}

struct ACPSetSessionModelParams: Encodable {
    let sessionId: String
    let modelId: String
}

struct ACPCancelParams: Encodable {
    let sessionId: String
}

struct ACPPromptParams: Encodable {
    let sessionId: String
    let prompt: [ACPContentBlock]
}

struct ACPContentBlock: Encodable {
    let type: String
    let text: String?

    static func text(_ text: String) -> ACPContentBlock {
        ACPContentBlock(type: "text", text: text)
    }
}

struct ACPPromptResult: Decodable {
    let stopReason: String?
}

// session/update notification payload. ACP packs many update kinds into one
// envelope distinguished by `sessionUpdate`. We surface only the kinds the UI
// renders today; everything else is reported as `unknown` for logging.
struct ACPSessionUpdateNotification: Decodable {
    let sessionId: String
    let update: ACPSessionUpdate

    private enum TopKeys: String, CodingKey { case sessionId }

    // ACPSessionUpdate reads from the top-level params object (not a nested key),
    // so we must pass the same decoder rather than a sub-decoder for an "update" key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TopKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        update = try ACPSessionUpdate(from: decoder)
    }
}

enum ACPSessionUpdate: Decodable {
    case agentMessageChunk(text: String)
    case agentThoughtChunk(text: String)
    case userMessageChunk(text: String)
    case toolCall(id: String, title: String, status: String, kind: String?)
    case toolCallUpdate(id: String, title: String?, status: String?, content: String?)
    case availableCommands(names: [String])
    case unknown(kind: String)

    private enum CodingKeys: String, CodingKey {
        case sessionUpdate
        case content
        case toolCallId
        case title
        case status
        case kind
        case availableCommands
    }

    private enum ContentKeys: String, CodingKey {
        case type
        case text
    }

    private enum CommandKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .sessionUpdate)

        switch kind {
        case "agent_message_chunk":
            let text = (try? Self.decodeContentText(in: container)) ?? ""
            self = .agentMessageChunk(text: text)
        case "agent_thought_chunk":
            let text = (try? Self.decodeContentText(in: container)) ?? ""
            self = .agentThoughtChunk(text: text)
        case "user_message_chunk":
            let text = (try? Self.decodeContentText(in: container)) ?? ""
            self = .userMessageChunk(text: text)
        case "tool_call":
            let id = (try? container.decode(String.self, forKey: .toolCallId)) ?? ""
            let title = (try? container.decode(String.self, forKey: .title)) ?? "Tool call"
            let status = (try? container.decode(String.self, forKey: .status)) ?? "pending"
            let toolKind = try? container.decode(String.self, forKey: .kind)
            self = .toolCall(id: id, title: title, status: status, kind: toolKind)
        case "tool_call_update":
            let id = (try? container.decode(String.self, forKey: .toolCallId)) ?? ""
            let title = try? container.decode(String.self, forKey: .title)
            let status = try? container.decode(String.self, forKey: .status)
            let content = try? Self.decodeContentText(in: container)
            self = .toolCallUpdate(id: id, title: title, status: status, content: content)
        case "available_commands_update":
            var names: [String] = []
            if var commands = try? container.nestedUnkeyedContainer(forKey: .availableCommands) {
                while !commands.isAtEnd {
                    if let cmd = try? commands.nestedContainer(keyedBy: CommandKeys.self),
                       let name = try? cmd.decode(String.self, forKey: .name) {
                        names.append(name)
                    } else {
                        _ = try? commands.decode(ACPEmpty.self)
                    }
                }
            }
            self = .availableCommands(names: names)
        default:
            self = .unknown(kind: kind)
        }
    }

    private static func decodeContentText(in container: KeyedDecodingContainer<CodingKeys>) throws -> String {
        let content = try container.nestedContainer(keyedBy: ContentKeys.self, forKey: .content)
        return try content.decode(String.self, forKey: .text)
    }
}

// Permission request from agent → client. Client must reply with the chosen optionId.
struct ACPRequestPermissionParams: Decodable {
    let sessionId: String
    let toolCall: ACPRequestPermissionToolCall
    let options: [ACPPermissionOption]
}

struct ACPRequestPermissionToolCall: Decodable {
    let toolCallId: String
    let title: String?
    let kind: String?
    let status: String?
}

struct ACPPermissionOption: Decodable {
    let optionId: String
    let name: String
    let kind: String
}

struct ACPRequestPermissionResult: Encodable {
    let outcome: ACPPermissionOutcome
}

struct ACPPermissionOutcome: Encodable {
    let outcome: String  // "selected" or "cancelled"
    let optionId: String?
}
