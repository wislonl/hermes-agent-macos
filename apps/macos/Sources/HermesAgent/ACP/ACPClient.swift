import Foundation

// Events emitted from the ACP client up to the UI layer. We translate raw
// `session/update` notifications into UI-friendly cases so SwiftUI never has
// to know the wire shape.

enum ACPEvent {
    case agentMessageChunk(sessionId: String, text: String)
    case agentThoughtChunk(sessionId: String, text: String)
    case toolCall(sessionId: String, id: String, title: String, status: String)
    case toolCallUpdate(sessionId: String, id: String, title: String?, status: String?, content: String?)
    case availableCommands(sessionId: String, names: [String])
    case unknown(method: String)
}

// Permission requests use a sync-ish flow: the client must respond with the
// chosen optionId. The UI presents a sheet and resolves the continuation.
struct ACPPermissionRequest {
    let id: JsonRpcId
    let sessionId: String
    let toolCallId: String
    let title: String
    let options: [ACPPermissionOption]
}

protocol ACPClientDelegate: AnyObject, Sendable {
    func acpClient(_ client: ACPClient, didEmit event: ACPEvent) async
    func acpClient(_ client: ACPClient, didRequestPermission request: ACPPermissionRequest) async
    func acpClientDidExit(_ client: ACPClient, error: Error?) async
}

final class ACPClient: @unchecked Sendable {
    private let transport: JsonRpcTransport
    private weak var delegate: ACPClientDelegate?

    init(executableURL: URL, arguments: [String] = ["acp"], extraEnvironment: [String: String] = [:]) {
        self.transport = JsonRpcTransport(
            executableURL: executableURL,
            arguments: arguments,
            extraEnvironment: extraEnvironment
        )
    }

    func start(delegate: ACPClientDelegate) async throws {
        self.delegate = delegate
        let weakSelf = WeakBox(self)
        try await transport.start(
            onNotification: { method, params in
                Task { await weakSelf.value?.handleNotification(method: method, params: params) }
            },
            onRequest: { id, method, params in
                Task { await weakSelf.value?.handleRequest(id: id, method: method, params: params) }
            }
        )
    }

    func stop() async {
        await transport.stop()
    }

    // MARK: - Public API

    func initialize() async throws -> ACPInitializeResult {
        let params = ACPInitializeParams(protocolVersion: 1, clientCapabilities: ACPClientCapabilities())
        return try await transport.sendRequest(method: ACPMethod.initialize, params: params, resultType: ACPInitializeResult.self)
    }

    func newSession(cwd: String) async throws -> ACPNewSessionResult {
        let params = ACPNewSessionParams(cwd: cwd, mcpServers: [])
        return try await transport.sendRequest(method: ACPMethod.newSession, params: params, resultType: ACPNewSessionResult.self)
    }

    func loadSession(sessionId: String, cwd: String) async throws -> ACPLoadSessionResult {
        let params = ACPLoadSessionParams(cwd: cwd, sessionId: sessionId, mcpServers: [])
        return try await transport.sendRequest(method: ACPMethod.loadSession, params: params, resultType: ACPLoadSessionResult.self)
    }

    func listSessions(cwd: String? = nil, cursor: String? = nil) async throws -> ACPListSessionsResult {
        let params = ACPListSessionsParams(cwd: cwd, cursor: cursor)
        return try await transport.sendRequest(method: ACPMethod.listSessions, params: params, resultType: ACPListSessionsResult.self)
    }

    func setSessionModel(sessionId: String, modelId: String) async throws {
        let params = ACPSetSessionModelParams(sessionId: sessionId, modelId: modelId)
        _ = try await transport.sendRequest(method: ACPMethod.setSessionModel, params: params, resultType: ACPEmpty.self)
    }

    func cancel(sessionId: String) async throws {
        let params = ACPCancelParams(sessionId: sessionId)
        try await transport.sendNotification(method: ACPMethod.cancel, params: params)
    }

    func prompt(sessionId: String, text: String) async throws -> ACPPromptResult {
        let params = ACPPromptParams(sessionId: sessionId, prompt: [.text(text)])
        return try await transport.sendRequest(method: ACPMethod.prompt, params: params, resultType: ACPPromptResult.self)
    }

    func respondToPermission(id: JsonRpcId, optionId: String?) async throws {
        let result: ACPRequestPermissionResult
        if let optionId = optionId {
            result = ACPRequestPermissionResult(outcome: ACPPermissionOutcome(outcome: "selected", optionId: optionId))
        } else {
            result = ACPRequestPermissionResult(outcome: ACPPermissionOutcome(outcome: "cancelled", optionId: nil))
        }
        try await transport.sendResponse(id: id, result: result)
    }

    // MARK: - Inbound

    private func handleNotification(method: String, params: Data) async {
        guard method == ACPMethod.sessionUpdate else {
            await delegate?.acpClient(self, didEmit: .unknown(method: method))
            return
        }
        do {
            let notification = try JSONDecoder().decode(ACPSessionUpdateNotification.self, from: params)
            for event in events(from: notification) {
                await delegate?.acpClient(self, didEmit: event)
            }
        } catch {
            await delegate?.acpClient(self, didEmit: .unknown(method: method))
        }
    }

    private func handleRequest(id: JsonRpcId, method: String, params: Data) async {
        guard method == ACPMethod.requestPermission else {
            try? await transport.sendErrorResponse(id: id, code: -32601, message: "Unsupported method: \(method)")
            return
        }
        do {
            let payload = try JSONDecoder().decode(ACPRequestPermissionParams.self, from: params)
            let request = ACPPermissionRequest(
                id: id,
                sessionId: payload.sessionId,
                toolCallId: payload.toolCall.toolCallId,
                title: payload.toolCall.title ?? "Permission required",
                options: payload.options
            )
            await delegate?.acpClient(self, didRequestPermission: request)
        } catch {
            try? await transport.sendErrorResponse(id: id, code: -32602, message: "Invalid permission request: \(error)")
        }
    }

    private func events(from notification: ACPSessionUpdateNotification) -> [ACPEvent] {
        switch notification.update {
        case .agentMessageChunk(let text):
            return [.agentMessageChunk(sessionId: notification.sessionId, text: text)]
        case .agentThoughtChunk(let text):
            return [.agentThoughtChunk(sessionId: notification.sessionId, text: text)]
        case .userMessageChunk:
            return []
        case .toolCall(let id, let title, let status, _):
            return [.toolCall(sessionId: notification.sessionId, id: id, title: title, status: status)]
        case .toolCallUpdate(let id, let title, let status, let content):
            return [.toolCallUpdate(sessionId: notification.sessionId, id: id, title: title, status: status, content: content)]
        case .availableCommands(let names):
            return [.availableCommands(sessionId: notification.sessionId, names: names)]
        case .unknown(let kind):
            return [.unknown(method: "session/update:\(kind)")]
        }
    }
}

private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
