import Foundation

enum RuntimeEvent: Decodable, Equatable {
    case messageDelta(runId: String, delta: String)
    case toolRequested(runId: String, toolCallId: String, tool: String, summary: String)
    case approvalRequired(runId: String, approvalId: String, toolCallId: String, command: String)
    case runCompleted(runId: String, status: String)

    private enum CodingKeys: String, CodingKey {
        case event
        case runId
        case delta
        case toolCallId
        case tool
        case summary
        case approvalId
        case operation
        case status
    }

    private enum OperationKeys: String, CodingKey {
        case command
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let event = try container.decode(String.self, forKey: .event)

        switch event {
        case "message.delta":
            self = .messageDelta(
                runId: try container.decode(String.self, forKey: .runId),
                delta: try container.decode(String.self, forKey: .delta)
            )
        case "tool.requested":
            self = .toolRequested(
                runId: try container.decode(String.self, forKey: .runId),
                toolCallId: try container.decode(String.self, forKey: .toolCallId),
                tool: try container.decode(String.self, forKey: .tool),
                summary: try container.decode(String.self, forKey: .summary)
            )
        case "approval.required":
            let operation = try container.nestedContainer(keyedBy: OperationKeys.self, forKey: .operation)
            self = .approvalRequired(
                runId: try container.decode(String.self, forKey: .runId),
                approvalId: try container.decode(String.self, forKey: .approvalId),
                toolCallId: try container.decode(String.self, forKey: .toolCallId),
                command: try operation.decode(String.self, forKey: .command)
            )
        case "run.completed":
            self = .runCompleted(
                runId: try container.decode(String.self, forKey: .runId),
                status: try container.decode(String.self, forKey: .status)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .event,
                in: container,
                debugDescription: "Unsupported runtime event: \(event)"
            )
        }
    }
}
