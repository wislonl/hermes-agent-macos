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

enum ProviderSelection: CaseIterable, Identifiable {
    case echo
    case deepSeek
    case openAI
    case openRouter
    case together
    case fireworks
    case groq
    case moonshot
    case qwen
    case zhipu
    case minimax
    case minimaxChina
    case volcengineArk
    case ollama
    case openAICompatible

    var id: String { storageValue }

    var storageValue: String {
        switch self {
        case .echo:
            "echo"
        case .deepSeek:
            "deepseek"
        case .openAI:
            "openai"
        case .openRouter:
            "openrouter"
        case .together:
            "together"
        case .fireworks:
            "fireworks"
        case .groq:
            "groq"
        case .moonshot:
            "moonshot"
        case .qwen:
            "qwen"
        case .zhipu:
            "zhipu"
        case .minimax:
            "minimax"
        case .minimaxChina:
            "minimax-china"
        case .volcengineArk:
            "volcengine-ark"
        case .ollama:
            "ollama"
        case .openAICompatible:
            "openai-compatible"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "echo":
            self = .echo
        case "deepseek":
            self = .deepSeek
        case "openai":
            self = .openAI
        case "openrouter":
            self = .openRouter
        case "together":
            self = .together
        case "fireworks":
            self = .fireworks
        case "groq":
            self = .groq
        case "moonshot":
            self = .moonshot
        case "qwen":
            self = .qwen
        case "zhipu":
            self = .zhipu
        case "minimax":
            self = .minimax
        case "minimax-china":
            self = .minimaxChina
        case "volcengine-ark":
            self = .volcengineArk
        case "ollama":
            self = .ollama
        case "openai-compatible":
            self = .openAICompatible
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .echo:
            "Echo"
        case .deepSeek:
            "DeepSeek V4 Pro"
        case .openAI:
            "OpenAI"
        case .openRouter:
            "OpenRouter"
        case .together:
            "Together"
        case .fireworks:
            "Fireworks"
        case .groq:
            "Groq"
        case .moonshot:
            "Moonshot / Kimi"
        case .qwen:
            "Qwen / Bailian"
        case .zhipu:
            "Zhipu / GLM"
        case .minimax:
            "MiniMax (Global)"
        case .minimaxChina:
            "MiniMax (China)"
        case .volcengineArk:
            "Volcengine Ark"
        case .ollama:
            "Ollama"
        case .openAICompatible:
            "OpenAI-compatible"
        }
    }

    static func inferred(baseURL: String) -> ProviderSelection? {
        let normalized = baseURL.lowercased()
        if normalized.contains("api.minimaxi.com") {
            return .minimaxChina
        }
        if normalized.contains("api.minimax.io") {
            return .minimax
        }
        if normalized.contains("api.deepseek.com") {
            return .deepSeek
        }
        if normalized.contains("api.openai.com") {
            return .openAI
        }
        if normalized.contains("openrouter.ai") {
            return .openRouter
        }
        if normalized.contains("dashscope.aliyuncs.com") {
            return .qwen
        }
        if normalized.contains("moonshot.ai") {
            return .moonshot
        }
        if normalized.contains("bigmodel.cn") {
            return .zhipu
        }
        if normalized.contains("volces.com") {
            return .volcengineArk
        }
        if normalized.contains("localhost:11434") {
            return .ollama
        }
        return .openAICompatible
    }
}

struct ProviderPreset: Equatable {
    let provider: ProviderSelection
    let baseURL: String
    let models: [String]
    let requiresAPIKey: Bool
    let thinkingEnabled: Bool
    let reasoningEffort: String?

    var defaultModel: String { models.first ?? "" }

    static func preset(for provider: ProviderSelection) -> ProviderPreset? {
        switch provider {
        case .echo:
            nil
        case .deepSeek:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.deepseek.com",
                models: ["deepseek-v4-pro", "deepseek-v4-flash"],
                requiresAPIKey: true,
                thinkingEnabled: true,
                reasoningEffort: "high"
            )
        case .openAI:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.openai.com/v1",
                models: ["gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.5"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .openRouter:
            ProviderPreset(
                provider: provider,
                baseURL: "https://openrouter.ai/api/v1",
                models: ["openrouter/auto", "openai/gpt-5.4", "deepseek/deepseek-v4-pro", "anthropic/claude-sonnet-4.6"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .together:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.together.xyz/v1",
                models: ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "Qwen/Qwen3-235B-A22B-Instruct-2507-tput"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .fireworks:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.fireworks.ai/inference/v1",
                models: ["accounts/fireworks/models/llama-v3p1-405b-instruct", "accounts/fireworks/models/kimi-k2-instruct-0905"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .groq:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.groq.com/openai/v1",
                models: ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .moonshot:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.moonshot.ai/v1",
                models: ["kimi-k2.6", "kimi-k2.5", "kimi-k2-thinking-turbo"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .qwen:
            ProviderPreset(
                provider: provider,
                baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                models: ["qwen-plus", "qwen-max", "qwen-turbo"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .zhipu:
            ProviderPreset(
                provider: provider,
                baseURL: "https://open.bigmodel.cn/api/paas/v4",
                models: ["glm-4.5", "glm-4.5-air"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .minimax:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.minimax.io/v1",
                models: ["MiniMax-M2.7", "MiniMax-M2.7-highspeed"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .minimaxChina:
            ProviderPreset(
                provider: provider,
                baseURL: "https://api.minimaxi.com/v1",
                models: ["MiniMax-M2.7", "MiniMax-M2.7-highspeed"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .volcengineArk:
            ProviderPreset(
                provider: provider,
                baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                models: ["doubao-seed-1-6-251015", "doubao-seed-1-6-flash-251015"],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .ollama:
            ProviderPreset(
                provider: provider,
                baseURL: "http://localhost:11434/v1",
                models: ["llama3.3", "qwen3", "gpt-oss:20b"],
                requiresAPIKey: false,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        case .openAICompatible:
            ProviderPreset(
                provider: provider,
                baseURL: "",
                models: [""],
                requiresAPIKey: true,
                thinkingEnabled: false,
                reasoningEffort: nil
            )
        }
    }
}

@Observable
final class AppState {
    typealias RuntimeClientFactory = (_ runtimeURL: URL, _ extraEnvironment: [String: String]) -> RuntimeClient

    @ObservationIgnored private var runtimeClient: RuntimeClient
    @ObservationIgnored private let runtimeClientFactory: RuntimeClientFactory
    @ObservationIgnored private let secretStore: SecretStore
    @ObservationIgnored private let runtimeURL: URL
    @ObservationIgnored let providerDefaults: UserDefaults
    @ObservationIgnored private let ownsRuntimeClient: Bool
    @ObservationIgnored private var cachedProviderEnvironment: [String: String]?
    private let sessionId: String
    private let workspacePath: String

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
    var selectedProvider: ProviderSelection = .deepSeek
    var deepSeekAPIKeyDraft = ""
    var providerBaseURLDraft = ""
    var providerModelDraft = ""
    var providerAPIKeyDraft = ""
    var providerAPIKeyIsSaved = false
    var providerThinkingEnabled = false
    var providerReasoningEffortDraft = ""
    var providerStatusMessage = "DeepSeek provider is not configured."
    var isTestingProvider = false

    init(
        runtimeClient: RuntimeClient? = nil,
        runtimeClientFactory: @escaping RuntimeClientFactory = { runtimeURL, extraEnvironment in
            ProcessRuntimeClient(runtimeURL: runtimeURL, extraEnvironment: extraEnvironment)
        },
        secretStore: SecretStore = KeychainStore(),
        runtimeURL: URL = RuntimeConfiguration.defaultRuntimeURL(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        providerDefaults: UserDefaults = .standard,
        sessionId: String = "session_default",
        workspacePath: String = FileManager.default.currentDirectoryPath
    ) {
        self.runtimeClientFactory = runtimeClientFactory
        self.secretStore = secretStore
        self.runtimeURL = runtimeURL
        self.providerDefaults = providerDefaults
        self.ownsRuntimeClient = runtimeClient == nil
        self.sessionId = sessionId
        self.workspacePath = workspacePath
        let initialProvider = ProviderPreferences.selectedProvider(defaults: providerDefaults)
        self.selectedProvider = initialProvider
        let preset = ProviderPreset.preset(for: initialProvider)
        self.providerBaseURLDraft = ProviderPreferences.providerBaseURL(defaults: providerDefaults) ?? preset?.baseURL ?? ""
        self.providerModelDraft = ProviderPreferences.providerModel(defaults: providerDefaults) ?? preset?.defaultModel ?? ""
        self.providerAPIKeyIsSaved = ProviderPreferences.apiKeySaved(defaults: providerDefaults)
        self.providerThinkingEnabled = ProviderPreferences.providerThinkingEnabled(defaults: providerDefaults) ?? preset?.thinkingEnabled ?? false
        self.providerReasoningEffortDraft = ProviderPreferences.providerReasoningEffort(defaults: providerDefaults) ?? preset?.reasoningEffort ?? ""
        let importedKey = RuntimeConfiguration.importDeepSeekAPIKeyIfNeeded(
            secretStore: secretStore,
            environment: environment,
            defaults: providerDefaults
        )
        self.runtimeClient = runtimeClient ?? runtimeClientFactory(runtimeURL, [:])
        if importedKey {
            providerStatusMessage = "DeepSeek API key imported from environment."
            cachedProviderEnvironment = RuntimeConfiguration.providerEnvironment(
                provider: .deepSeek,
                baseURL: providerBaseURLDraft,
                model: providerModelDraft,
                apiKey: environment["DEEPSEEK_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                thinkingEnabled: providerThinkingEnabled,
                reasoningEffort: providerReasoningEffortDraft
            )
        } else if initialProvider == .echo {
            providerStatusMessage = "Echo provider selected."
        } else {
            providerStatusMessage = "\(initialProvider.displayName) provider selected."
        }
    }

    func applyProviderPreset() {
        guard let preset = ProviderPreset.preset(for: selectedProvider) else {
            providerBaseURLDraft = ""
            providerModelDraft = ""
            providerThinkingEnabled = false
            providerReasoningEffortDraft = ""
            return
        }

        providerBaseURLDraft = preset.baseURL
        providerModelDraft = preset.defaultModel
        providerThinkingEnabled = preset.thinkingEnabled
        providerReasoningEffortDraft = preset.reasoningEffort ?? ""
    }

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
            if let index = approvals.firstIndex(where: { $0.id == approvalId }) {
                approvals[index] = ApprovalRequest(
                    id: approvalId,
                    command: command,
                    decision: approvals[index].decision
                )
            } else {
                approvals.append(ApprovalRequest(id: approvalId, command: command, decision: nil))
            }
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

    func submitDraft() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        draft = ""

        do {
            guard refreshRuntimeClientIfNeeded() else {
                messages.append(ChatMessage(
                    id: UUID(),
                    author: .system,
                    text: "Provider is not configured. Save an API key or select Echo explicitly."
                ))
                return
            }
            let run = try await runtimeClient.createRun(
                sessionId: sessionId,
                agentProfileId: selectedAgentId,
                input: trimmed,
                history: recentRunHistory(),
                workspacePath: workspacePath
            )
            for event in run.events {
                apply(event: event)
            }
        } catch {
            messages.append(ChatMessage(
                id: UUID(),
                author: .system,
                text: "Runtime request failed: \(error.localizedDescription)"
            ))
        }
    }

    private func recentRunHistory(limit: Int = 12) -> [RunHistoryMessage] {
        messages
            .compactMap { message -> RunHistoryMessage? in
                switch message.author {
                case .user:
                    return RunHistoryMessage(role: "user", content: message.text)
                case .assistant:
                    guard message.text != "Hermes is ready." else { return nil }
                    return RunHistoryMessage(role: "assistant", content: message.text)
                case .system:
                    return nil
                }
            }
            .suffix(limit)
            .map { $0 }
    }

    func testProviderConfiguration() async {
        guard !isTestingProvider else { return }
        isTestingProvider = true
        providerStatusMessage = "Testing provider..."
        defer { isTestingProvider = false }

        do {
            guard refreshRuntimeClientIfNeeded() else {
                providerStatusMessage = "Provider is not configured. Save an API key or select Echo explicitly."
                return
            }
            let result = try await runtimeClient.testProvider()
            providerStatusMessage = "\(result.provider) \(result.model) connection ok."
        } catch {
            providerStatusMessage = "Provider test failed: \(error.localizedDescription)"
        }
    }

    func saveDeepSeekAPIKey() throws {
        let key = deepSeekAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        try secretStore.setSecret(key, account: ProviderSecrets.deepSeekAPIKeyAccount)
        if let preset = ProviderPreset.preset(for: .deepSeek) {
            providerBaseURLDraft = preset.baseURL
            providerModelDraft = preset.defaultModel
            providerThinkingEnabled = preset.thinkingEnabled
            providerReasoningEffortDraft = preset.reasoningEffort ?? ""
            ProviderPreferences.save(
                provider: .deepSeek,
                baseURL: preset.baseURL,
                model: preset.defaultModel,
                thinkingEnabled: preset.thinkingEnabled,
                reasoningEffort: preset.reasoningEffort ?? "",
                defaults: providerDefaults
            )
        }
        try secretStore.setSecret(key, account: ProviderSecrets.providerAPIKeyAccount)
        providerAPIKeyIsSaved = true
        ProviderPreferences.saveAPIKeySaved(true, defaults: providerDefaults)
        selectedProvider = .deepSeek
        deepSeekAPIKeyDraft = ""
        providerStatusMessage = "DeepSeek API key saved."
        cachedProviderEnvironment = RuntimeConfiguration.providerEnvironment(
            provider: selectedProvider,
            baseURL: providerBaseURLDraft,
            model: providerModelDraft,
            apiKey: key,
            thinkingEnabled: providerThinkingEnabled,
            reasoningEffort: providerReasoningEffortDraft
        )
        runtimeClient = runtimeClientFactory(
            runtimeURL,
            cachedProviderEnvironment ?? [:]
        )
    }

    func saveProviderConfiguration() throws {
        switch selectedProvider {
        case .echo:
            ProviderPreferences.save(provider: .echo, defaults: providerDefaults)
            cachedProviderEnvironment = [:]
            providerStatusMessage = "Echo provider selected."
        case .deepSeek, .openAI, .openRouter, .together, .fireworks, .groq, .moonshot, .qwen, .zhipu, .minimax, .minimaxChina, .volcengineArk, .ollama, .openAICompatible:
            let baseURL = providerBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = providerModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = providerAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let requiresAPIKey = ProviderPreset.preset(for: selectedProvider)?.requiresAPIKey ?? true
            guard !baseURL.isEmpty, !model.isEmpty, !requiresAPIKey || !apiKey.isEmpty || providerAPIKeyIsSaved else { return }

            let reasoningEffort = providerReasoningEffortDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            ProviderPreferences.save(
                provider: selectedProvider,
                baseURL: baseURL,
                model: model,
                thinkingEnabled: providerThinkingEnabled,
                reasoningEffort: reasoningEffort,
                defaults: providerDefaults
            )
            var savedAPIKey: String?
            if requiresAPIKey {
                if apiKey.isEmpty {
                    savedAPIKey = try secretStore.getSecret(account: ProviderSecrets.providerAPIKeyAccount)
                    guard savedAPIKey?.isEmpty == false else { return }
                } else {
                    try secretStore.setSecret(apiKey, account: ProviderSecrets.providerAPIKeyAccount)
                    savedAPIKey = apiKey
                    providerAPIKeyIsSaved = true
                    ProviderPreferences.saveAPIKeySaved(true, defaults: providerDefaults)
                    if selectedProvider == .deepSeek {
                        try secretStore.setSecret(apiKey, account: ProviderSecrets.deepSeekAPIKeyAccount)
                    }
                }
            } else {
                try secretStore.deleteSecret(account: ProviderSecrets.providerAPIKeyAccount)
                providerAPIKeyIsSaved = false
                ProviderPreferences.saveAPIKeySaved(false, defaults: providerDefaults)
            }
            providerAPIKeyDraft = ""
            providerStatusMessage = "\(selectedProvider.displayName) provider saved."
            cachedProviderEnvironment = RuntimeConfiguration.providerEnvironment(
                provider: selectedProvider,
                baseURL: baseURL,
                model: model,
                apiKey: requiresAPIKey ? savedAPIKey : "ollama",
                thinkingEnabled: providerThinkingEnabled,
                reasoningEffort: reasoningEffort
            )
        }

        runtimeClient = runtimeClientFactory(
            runtimeURL,
            cachedProviderEnvironment ?? [:]
        )
    }

    func clearProviderAPIKey() throws {
        try secretStore.deleteSecret(account: ProviderSecrets.providerAPIKeyAccount)
        providerAPIKeyDraft = ""
        providerAPIKeyIsSaved = false
        ProviderPreferences.saveAPIKeySaved(false, defaults: providerDefaults)
        cachedProviderEnvironment = nil
        providerStatusMessage = "Provider API key cleared."
        runtimeClient = runtimeClientFactory(runtimeURL, [:])
    }

    @discardableResult
    private func refreshRuntimeClientIfNeeded() -> Bool {
        guard ownsRuntimeClient else { return true }

        if cachedProviderEnvironment == nil {
            if ProviderPreferences.hasProviderConfiguration(defaults: providerDefaults) {
                cachedProviderEnvironment = RuntimeConfiguration.providerEnvironment(
                    secretStore: secretStore,
                    defaults: providerDefaults
                )
                if cachedProviderEnvironment?.isEmpty != false {
                    cachedProviderEnvironment = migrateLegacyProviderConfigurationIfAvailable()
                }
            } else {
                cachedProviderEnvironment = migrateLegacyProviderConfigurationIfAvailable()
                if cachedProviderEnvironment?.isEmpty != false {
                    cachedProviderEnvironment = RuntimeConfiguration.providerEnvironment(
                        secretStore: secretStore,
                        defaults: providerDefaults
                    )
                }
            }
        }
        runtimeClient = runtimeClientFactory(runtimeURL, cachedProviderEnvironment ?? [:])
        return selectedProvider == .echo || cachedProviderEnvironment?.isEmpty == false
    }

    private func migrateLegacyProviderConfigurationIfAvailable() -> [String: String] {
        guard
            let apiKey = try? secretStore.getSecret(account: ProviderSecrets.providerAPIKeyAccount),
            !apiKey.isEmpty
        else {
            return [:]
        }

        let legacyBaseURL = (try? secretStore.getSecret(account: ProviderSecrets.legacyProviderBaseURLAccount)) ?? ""
        let legacyModel = (try? secretStore.getSecret(account: ProviderSecrets.legacyProviderModelAccount)) ?? ""
        let legacyProviderRaw = try? secretStore.getSecret(account: ProviderSecrets.legacySelectedProviderAccount)
        let migratedProvider = legacyProviderRaw.flatMap(ProviderSelection.init(storageValue:))
            ?? ProviderSelection.inferred(baseURL: legacyBaseURL)
            ?? selectedProvider
        let preset = ProviderPreset.preset(for: migratedProvider)
        let baseURL = legacyBaseURL.isEmpty ? (preset?.baseURL ?? providerBaseURLDraft) : legacyBaseURL
        let model = legacyModel.isEmpty ? (preset?.defaultModel ?? providerModelDraft) : legacyModel
        guard !baseURL.isEmpty, !model.isEmpty else {
            return [:]
        }

        selectedProvider = migratedProvider
        providerBaseURLDraft = baseURL
        providerModelDraft = model
        providerThinkingEnabled = preset?.thinkingEnabled ?? providerThinkingEnabled
        providerReasoningEffortDraft = preset?.reasoningEffort ?? providerReasoningEffortDraft
        providerAPIKeyIsSaved = true
        ProviderPreferences.save(
            provider: migratedProvider,
            baseURL: baseURL,
            model: model,
            thinkingEnabled: providerThinkingEnabled,
            reasoningEffort: providerReasoningEffortDraft,
            defaults: providerDefaults
        )
        ProviderPreferences.saveAPIKeySaved(true, defaults: providerDefaults)
        providerStatusMessage = "\(migratedProvider.displayName) provider restored from saved key."
        return RuntimeConfiguration.providerEnvironment(
            provider: migratedProvider,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            thinkingEnabled: providerThinkingEnabled,
            reasoningEffort: providerReasoningEffortDraft
        )
    }
}

enum ProviderSecrets {
    static let deepSeekAPIKeyAccount = "provider.deepseek.api_key"
    static let providerAPIKeyAccount = "provider.openai_compatible.api_key"
    static let legacySelectedProviderAccount = "provider.selected"
    static let legacyProviderBaseURLAccount = "provider.openai_compatible.base_url"
    static let legacyProviderModelAccount = "provider.openai_compatible.model"

    static var openAICompatibleAPIKeyAccount: String { providerAPIKeyAccount }
}

enum ProviderPreferences {
    private static let selectedProviderKey = "provider.selected"
    private static let baseURLKey = "provider.openai_compatible.base_url"
    private static let modelKey = "provider.openai_compatible.model"
    private static let apiKeySavedKey = "provider.openai_compatible.api_key_saved"
    private static let thinkingEnabledKey = "provider.openai_compatible.thinking_enabled"
    private static let reasoningEffortKey = "provider.openai_compatible.reasoning_effort"

    static func save(provider: ProviderSelection, defaults: UserDefaults) {
        defaults.set(provider.storageValue, forKey: selectedProviderKey)
    }

    static func save(
        provider: ProviderSelection,
        baseURL: String,
        model: String,
        thinkingEnabled: Bool,
        reasoningEffort: String,
        defaults: UserDefaults
    ) {
        defaults.set(provider.storageValue, forKey: selectedProviderKey)
        defaults.set(baseURL, forKey: baseURLKey)
        defaults.set(model, forKey: modelKey)
        defaults.set(thinkingEnabled, forKey: thinkingEnabledKey)
        defaults.set(reasoningEffort, forKey: reasoningEffortKey)
    }

    static func selectedProvider(defaults: UserDefaults) -> ProviderSelection {
        guard
            let rawValue = defaults.string(forKey: selectedProviderKey),
            let provider = ProviderSelection(storageValue: rawValue)
        else {
            return .deepSeek
        }

        return provider
    }

    static func providerBaseURL(defaults: UserDefaults) -> String? {
        defaults.string(forKey: baseURLKey)
    }

    static func providerModel(defaults: UserDefaults) -> String? {
        defaults.string(forKey: modelKey)
    }

    static func hasProviderConfiguration(defaults: UserDefaults) -> Bool {
        defaults.string(forKey: selectedProviderKey) != nil
            || defaults.string(forKey: baseURLKey) != nil
            || defaults.string(forKey: modelKey) != nil
    }

    static func saveAPIKeySaved(_ isSaved: Bool, defaults: UserDefaults) {
        defaults.set(isSaved, forKey: apiKeySavedKey)
    }

    static func apiKeySaved(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: apiKeySavedKey)
    }

    static func providerThinkingEnabled(defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: thinkingEnabledKey) != nil else { return nil }
        return defaults.bool(forKey: thinkingEnabledKey)
    }

    static func providerReasoningEffort(defaults: UserDefaults) -> String? {
        defaults.string(forKey: reasoningEffortKey)
    }
}

enum RuntimeConfiguration {
    static func importDeepSeekAPIKeyIfNeeded(
        secretStore: SecretStore,
        environment: [String: String],
        defaults: UserDefaults
    ) -> Bool {
        guard
            let rawKey = environment["DEEPSEEK_API_KEY"],
            !rawKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        do {
            try secretStore.setSecret(
                rawKey.trimmingCharacters(in: .whitespacesAndNewlines),
                account: ProviderSecrets.deepSeekAPIKeyAccount
            )
            if let preset = ProviderPreset.preset(for: .deepSeek) {
                ProviderPreferences.save(
                    provider: .deepSeek,
                    baseURL: preset.baseURL,
                    model: preset.defaultModel,
                    thinkingEnabled: preset.thinkingEnabled,
                    reasoningEffort: preset.reasoningEffort ?? "",
                    defaults: defaults
                )
            }
            try secretStore.setSecret(
                rawKey.trimmingCharacters(in: .whitespacesAndNewlines),
                account: ProviderSecrets.providerAPIKeyAccount
            )
            return true
        } catch {
            return false
        }
    }

    static func providerEnvironment(secretStore: SecretStore, defaults: UserDefaults) -> [String: String] {
        let provider = ProviderPreferences.selectedProvider(defaults: defaults)
        switch provider {
        case .echo:
            return [:]
        case .deepSeek, .openAI, .openRouter, .together, .fireworks, .groq, .moonshot, .qwen, .zhipu, .minimax, .minimaxChina, .volcengineArk, .ollama, .openAICompatible:
            let preset = ProviderPreset.preset(for: provider)
            let storedBaseURL = ProviderPreferences.providerBaseURL(defaults: defaults)
            let storedModel = ProviderPreferences.providerModel(defaults: defaults)
            guard
                let baseURL = storedBaseURL?.isEmpty == false ? storedBaseURL : preset?.baseURL,
                let model = storedModel?.isEmpty == false ? storedModel : preset?.defaultModel,
                !baseURL.isEmpty,
                !model.isEmpty
            else {
                return [:]
            }

            let apiKey: String?
            if preset?.requiresAPIKey == false {
                apiKey = "ollama"
            } else {
                apiKey = try? secretStore.getSecret(account: ProviderSecrets.providerAPIKeyAccount)
            }

            return providerEnvironment(
                provider: provider,
                baseURL: baseURL,
                model: model,
                apiKey: apiKey,
                thinkingEnabled: ProviderPreferences.providerThinkingEnabled(defaults: defaults) ?? preset?.thinkingEnabled ?? false,
                reasoningEffort: ProviderPreferences.providerReasoningEffort(defaults: defaults) ?? preset?.reasoningEffort ?? ""
            )
        }
    }

    static func providerEnvironment(
        provider: ProviderSelection,
        baseURL: String,
        model: String,
        apiKey: String?,
        thinkingEnabled: Bool,
        reasoningEffort: String
    ) -> [String: String] {
        guard
            !baseURL.isEmpty,
            !model.isEmpty,
            let apiKey,
            !apiKey.isEmpty
        else {
            return [:]
        }

        var environment = [
            "HERMES_PROVIDER": "openai-compatible",
            "OPENAI_COMPATIBLE_PROVIDER_NAME": provider.displayName,
            "OPENAI_COMPATIBLE_BASE_URL": baseURL,
            "OPENAI_COMPATIBLE_MODEL": model,
            "OPENAI_COMPATIBLE_API_KEY": apiKey
        ]
        if thinkingEnabled {
            environment["OPENAI_COMPATIBLE_THINKING"] = "enabled"
        }
        if !reasoningEffort.isEmpty {
            environment["OPENAI_COMPATIBLE_REASONING_EFFORT"] = reasoningEffort
        }
        return environment
    }

    static func defaultRuntimeURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) -> URL {
        if let explicitPath = environment["HERMES_RUNTIME_PATH"], !explicitPath.isEmpty {
            return URL(fileURLWithPath: explicitPath)
        }

        if let executableURL = Bundle.main.executableURL {
            let siblingRuntime = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("hermes-runtime")
            if FileManager.default.isExecutableFile(atPath: siblingRuntime.path) {
                return siblingRuntime
            }
        }

        let projectRuntime = URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent("crates/hermes-runtime/target/debug/hermes-runtime")
        if FileManager.default.isExecutableFile(atPath: projectRuntime.path) {
            return projectRuntime
        }

        return URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent("target/debug/hermes-runtime")
    }
}
