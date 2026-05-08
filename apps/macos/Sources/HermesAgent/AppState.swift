import Foundation
import Observation

@MainActor
@Observable
final class AppState: NSObject {
    enum ConnectionState: Equatable {
        case starting
        case ready
        case failed(String)
        case disconnected
    }

    var connectionState: ConnectionState = .starting
    var statusMessage: String = "Starting Hermes…"

    var sessions: [SessionSummary] = []
    var currentSessionId: String?
    var messages: [ChatMessage] = []
    var toolCalls: [ToolCallView] = []
    var pendingApproval: ApprovalPrompt?
    var availableModels: [AvailableModel] = []
    var currentModelId: String?
    var availableSlashCommands: [String] = []

    var draft: String = ""
    var isAwaitingResponse: Bool = false
    var isRestarting: Bool = false
    var workspacePath: String

    @ObservationIgnored private var client: ACPClient?
    @ObservationIgnored private var pendingPermission: ACPPermissionRequest?
    @ObservationIgnored private let executableURL: URL?
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var messageCache: [String: [ChatMessage]] = [:]
    @ObservationIgnored private var toolCallCache: [String: [ToolCallView]] = [:]

    init(workspacePath: String = AppState.defaultWorkspacePath,
         executableURL: URL? = HermesLocator.findExecutable()) {
        self.workspacePath = workspacePath
        self.executableURL = executableURL
        super.init()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        guard let executableURL else {
            connectionState = .failed("Could not find `hermes` on PATH. Install from https://hermes-agent.nousresearch.com.")
            statusMessage = "Hermes not found"
            return
        }
        let client = ACPClient(executableURL: executableURL)
        self.client = client

        Task { [weak self] in
            guard let self else { return }
            do {
                try await client.start(delegate: self)
                let info = try await client.initialize()
                let agentName = info.agentInfo?.name ?? "hermes-agent"
                let agentVersion = info.agentInfo?.version ?? "?"
                self.statusMessage = "Connected to \(agentName) v\(agentVersion)"
                await self.refreshSessions()
                await self.startNewSession()
                self.connectionState = .ready
            } catch {
                self.connectionState = .failed(error.localizedDescription)
                self.statusMessage = "Failed to start Hermes: \(error.localizedDescription)"
            }
        }
    }

    func shutdown() {
        Task { [client] in await client?.stop() }
    }

    // MARK: - User actions

    func submitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let sessionId = currentSessionId, let client else { return }

        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        draft = ""
        isAwaitingResponse = true
        messages.append(ChatMessage(id: UUID(), author: .agent, text: ""))

        Task { [weak self] in
            do {
                _ = try await client.prompt(sessionId: sessionId, text: trimmed)
            } catch {
                self?.appendSystem("Prompt failed: \(error.localizedDescription)")
            }
            self?.isAwaitingResponse = false
            // Refresh session list so the title updates after hermes generates one.
            await self?.refreshSessions()
        }
    }

    func startNewSession() async {
        guard let client else { return }
        saveCurrentSessionToCache()
        do {
            let result = try await client.newSession(cwd: workspacePath)
            self.currentSessionId = result.sessionId
            self.messages = []
            self.toolCalls = []
            self.applyModelState(result.models)
            self.availableSlashCommands.removeAll()
            // Hermes only includes sessions with messages in session/list, so insert
            // the new session into the local list immediately.
            let placeholder = SessionSummary(
                id: result.sessionId,
                title: "New conversation",
                cwd: workspacePath,
                updatedAt: nil
            )
            sessions.insert(placeholder, at: 0)
        } catch {
            appendSystem("Could not create session: \(error.localizedDescription)")
        }
    }

    func switchToSession(_ sessionId: String, cwd: String) async {
        guard let client, sessionId != currentSessionId else { return }
        saveCurrentSessionToCache()
        do {
            let result = try await client.loadSession(sessionId: sessionId, cwd: cwd)
            self.currentSessionId = sessionId
            self.workspacePath = cwd
            self.messages = messageCache[sessionId]
                ?? loadMessagesFromFile(sessionId: sessionId)
                ?? []
            self.toolCalls = toolCallCache[sessionId] ?? []
            self.availableSlashCommands.removeAll()
            self.applyModelState(result.models)
        } catch {
            appendSystem("Could not load session: \(error.localizedDescription)")
        }
    }

    private func saveCurrentSessionToCache() {
        guard let id = currentSessionId else { return }
        messageCache[id] = messages
        toolCallCache[id] = toolCalls
    }

    func setModel(_ modelId: String) async {
        guard let client, let sessionId = currentSessionId else { return }
        do {
            try await client.setSessionModel(sessionId: sessionId, modelId: modelId)
            self.currentModelId = modelId
        } catch {
            appendSystem("Model switch failed: \(error.localizedDescription)")
        }
    }

    func cancelCurrentRun() async {
        guard let client, let sessionId = currentSessionId else { return }
        try? await client.cancel(sessionId: sessionId)
    }

    func deleteSession(_ sessionId: String) {
        let filePath = NSHomeDirectory() + "/.hermes/sessions/session_\(sessionId).json"
        try? FileManager.default.removeItem(atPath: filePath)
        sessions.removeAll { $0.id == sessionId }
        messageCache.removeValue(forKey: sessionId)
        toolCallCache.removeValue(forKey: sessionId)
        if currentSessionId == sessionId {
            Task { await startNewSession() }
        }
    }

    func renameSession(_ sessionId: String, title: String) {
        // Update the local list immediately.
        if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[idx].title = title
        }
        // Persist to hermes session file.
        let filePath = NSHomeDirectory() + "/.hermes/sessions/session_\(sessionId).json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        json["title"] = title
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: URL(fileURLWithPath: filePath))
        }
    }

    func applyModelPreset(_ preset: ModelPreset, apiKey: String) async throws {
        try HermesConfig.writeEnvKey(preset.envKey, value: apiKey)
        try HermesConfig.writeConfigModel(modelId: preset.modelId, provider: preset.provider)
        await restartRuntime()
    }

    func restartRuntime() async {
        isRestarting = true
        await client?.stop()
        client = nil
        didStart = false
        connectionState = .starting
        statusMessage = "Restarting Hermes…"
        sessions = []
        currentSessionId = nil
        messages = []
        toolCalls = []
        availableModels = []
        currentModelId = nil
        messageCache = [:]
        toolCallCache = [:]
        startIfNeeded()
        isRestarting = false
    }

    func clearToolCalls() {
        toolCalls = []
        if let id = currentSessionId { toolCallCache[id] = [] }
    }

    func resolveApproval(optionId: String?) {
        guard let permission = pendingPermission, let client else { return }
        pendingPermission = nil
        pendingApproval = nil
        Task {
            try? await client.respondToPermission(id: permission.id, optionId: optionId)
        }
    }

    // MARK: - Private helpers

    // Read conversation history from hermes's session JSON file.
    // Returns nil if the file doesn't exist or can't be parsed.
    private func loadMessagesFromFile(sessionId: String) -> [ChatMessage]? {
        let path = NSHomeDirectory() + "/.hermes/sessions/session_\(sessionId).json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawMessages = json["messages"] as? [[String: Any]]
        else { return nil }

        var result: [ChatMessage] = []
        for msg in rawMessages {
            guard let role = msg["role"] as? String else { continue }
            switch role {
            case "user":
                let content = (msg["content"] as? String) ?? ""
                if !content.isEmpty {
                    result.append(ChatMessage(id: UUID(), author: .user, text: content))
                }
            case "assistant":
                let raw = (msg["content"] as? String) ?? ""
                let cleaned = raw.strippingHermesMarkup()
                if !cleaned.isEmpty {
                    result.append(ChatMessage(id: UUID(), author: .agent, text: cleaned))
                }
            default:
                break
            }
        }
        return result.isEmpty ? nil : result
    }

    private func refreshSessions() async {
        guard let client else { return }
        do {
            let result = try await client.listSessions(cwd: nil)
            self.sessions = result.sessions.map { info in
                SessionSummary(
                    id: info.sessionId,
                    title: info.title ?? "Untitled session",
                    cwd: info.cwd,
                    updatedAt: info.updatedAt
                )
            }
        } catch {
            // Non-fatal. Session list is informational.
        }
    }

    private func applyModelState(_ state: ACPSessionModelState?) {
        availableModels = (state?.availableModels ?? []).map {
            AvailableModel(id: $0.modelId, name: $0.name, description: $0.description)
        }
        currentModelId = state?.currentModelId
    }

    private func appendSystem(_ text: String) {
        messages.append(ChatMessage(id: UUID(), author: .system, text: text))
    }

    fileprivate func appendAgentChunk(text: String) {
        if let last = messages.last, last.author == .agent {
            messages[messages.count - 1].text += text
        } else {
            messages.append(ChatMessage(id: UUID(), author: .agent, text: text))
        }
    }

    fileprivate func upsertToolCall(id: String, title: String?, status: String?, detail: String?) {
        let mapStatus: (String?) -> ToolCallView.Status = { status in
            switch status {
            case "in_progress", "pending": return .running
            case "completed", "success": return .completed
            case "failed", "error": return .failed
            default: return .pending
            }
        }
        if let index = toolCalls.firstIndex(where: { $0.id == id }) {
            if let title { toolCalls[index].title = title }
            if let status { toolCalls[index].status = mapStatus(status) }
            if let detail, !detail.isEmpty { toolCalls[index].detail = detail }
        } else {
            toolCalls.append(ToolCallView(
                id: id,
                title: title ?? "Tool call",
                detail: detail ?? "",
                status: mapStatus(status)
            ))
        }
    }
}

// MARK: - ACP delegate

extension AppState: ACPClientDelegate {
    nonisolated func acpClient(_ client: ACPClient, didEmit event: ACPEvent) async {
        await MainActor.run {
            switch event {
            case .agentMessageChunk(let sessionId, let text):
                guard sessionId == self.currentSessionId else { break }
                self.appendAgentChunk(text: text)
            case .agentThoughtChunk:
                break
            case .toolCall(let sessionId, let id, let title, let status):
                guard sessionId == self.currentSessionId else { break }
                self.upsertToolCall(id: id, title: title, status: status, detail: nil)
            case .toolCallUpdate(let sessionId, let id, let title, let status, let content):
                guard sessionId == self.currentSessionId else { break }
                self.upsertToolCall(id: id, title: title, status: status, detail: content)
            case .availableCommands(let sessionId, let names):
                guard sessionId == self.currentSessionId else { break }
                self.availableSlashCommands = names
            case .unknown:
                break
            }
        }
    }

    nonisolated func acpClient(_ client: ACPClient, didRequestPermission request: ACPPermissionRequest) async {
        await MainActor.run {
            self.pendingPermission = request
            self.pendingApproval = ApprovalPrompt(
                id: request.toolCallId,
                toolCall: request.toolCallId,
                summary: request.title,
                options: request.options.map {
                    ApprovalPrompt.Option(id: $0.optionId, name: $0.name, kind: $0.kind)
                }
            )
        }
    }

    nonisolated func acpClientDidExit(_ client: ACPClient, error: Error?) async {
        await MainActor.run {
            self.connectionState = .disconnected
            self.statusMessage = error.map { "Hermes exited: \($0.localizedDescription)" } ?? "Hermes exited."
        }
    }
}

// MARK: - Defaults

extension AppState {
    // Prefer the user's home directory over whatever cwd the process inherits
    // (bundled .app launched from Finder gets cwd = "/").
    nonisolated static var defaultWorkspacePath: String {
        let cwd = FileManager.default.currentDirectoryPath
        return cwd == "/" ? NSHomeDirectory() : cwd
    }
}

// MARK: - Locating the hermes executable

enum HermesLocator {
    static func findExecutable(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let explicit = environment["HERMES_EXECUTABLE"], !explicit.isEmpty {
            let url = URL(fileURLWithPath: explicit)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }

        let candidates = [
            "\(NSHomeDirectory())/.local/bin/hermes",
            "/usr/local/bin/hermes",
            "/opt/homebrew/bin/hermes",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // Fallback: ask the user's login shell — covers pyenv shims and PATH oddities
        // when the app is launched from Finder (which has a minimal PATH).
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-l", "-c", "command -v hermes"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        } catch {
            return nil
        }
        return nil
    }
}
