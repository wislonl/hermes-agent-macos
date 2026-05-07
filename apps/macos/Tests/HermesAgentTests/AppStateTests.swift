import XCTest
@testable import HermesAgent

final class AppStateTests: XCTestCase {
    func testInitDoesNotReadKeychainSecrets() {
        let store = StubSecretStore()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))

        _ = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: isolatedProviderDefaults()
        )

        XCTAssertEqual(store.readAccounts, [])
        XCTAssertEqual(factory.environments.last, [:])
    }

    func testInitLoadsSavedAPIKeyMarkerWithoutReadingKeychain() {
        let store = StubSecretStore()
        let defaults = isolatedProviderDefaults()
        ProviderPreferences.saveAPIKeySaved(true, defaults: defaults)

        let state = AppState(secretStore: store, providerDefaults: defaults)

        XCTAssertTrue(state.providerAPIKeyIsSaved)
        XCTAssertEqual(store.readAccounts, [])
    }

    func testSubmitDraftAddsUserMessageAndClearsDraft() async {
        let state = AppState(runtimeClient: StubRuntimeClient(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: [.messageDelta(runId: "run_123", delta: "Runtime reply")]
        )))
        state.draft = "Hello Hermes"

        await state.submitDraft()

        XCTAssertEqual(state.messages.suffix(2).first?.text, "Hello Hermes")
        XCTAssertEqual(state.messages.suffix(2).first?.author, .user)
        XCTAssertEqual(state.messages.last?.text, "Runtime reply")
        XCTAssertEqual(state.draft, "")
    }

    func testSubmitDraftSendsOrdinaryInputThroughRuntimeRunCreate() async {
        let runtimeClient = StubRuntimeClient(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: [
                .messageDelta(runId: "run_123", delta: "Echo: Hello Hermes"),
                .runCompleted(runId: "run_123", status: "completed")
            ]
        ))
        let state = AppState(runtimeClient: runtimeClient, workspacePath: "/Users/example/project")
        state.draft = "Hello Hermes"

        await state.submitDraft()

        XCTAssertEqual(runtimeClient.requests, [
            StubRuntimeClient.Request(
                sessionId: "session_default",
                agentProfileId: "agent_hermes",
                input: "Hello Hermes",
                history: [
                    RunHistoryMessage(role: "user", content: "Hello Hermes")
                ],
                workspacePath: "/Users/example/project"
            )
        ])
        XCTAssertEqual(state.messages.last?.text, "Echo: Hello Hermes")
    }

    func testSubmitDraftSendsRecentUserAndAssistantHistoryThroughRuntimeRunCreate() async {
        let runtimeClient = StubRuntimeClient(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(runtimeClient: runtimeClient, workspacePath: "/Users/example/project")
        state.messages = [
            ChatMessage(id: UUID(), author: .system, text: "Provider saved."),
            ChatMessage(id: UUID(), author: .assistant, text: "Previous answer"),
            ChatMessage(id: UUID(), author: .user, text: "Previous question")
        ]
        state.draft = "Follow up"

        await state.submitDraft()

        XCTAssertEqual(runtimeClient.requests.last?.history, [
            RunHistoryMessage(role: "assistant", content: "Previous answer"),
            RunHistoryMessage(role: "user", content: "Previous question"),
            RunHistoryMessage(role: "user", content: "Follow up")
        ])
    }

    func testSubmitDraftBuildsRuntimeEnvironmentFromSavedProviderConfiguration() async {
        let store = StubSecretStore()
        store.secrets[ProviderSecrets.providerAPIKeyAccount] = "sk-saved"
        let defaults = isolatedProviderDefaults()
        ProviderPreferences.save(
            provider: .minimaxChina,
            baseURL: "https://api.minimaxi.com/v1",
            model: "MiniMax-M2.7-highspeed",
            thinkingEnabled: false,
            reasoningEffort: "",
            defaults: defaults
        )
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: defaults
        )
        state.draft = "Hello Hermes"

        await state.submitDraft()

        XCTAssertEqual(store.readAccounts, [ProviderSecrets.providerAPIKeyAccount])
        XCTAssertEqual(factory.environments.last?["HERMES_PROVIDER"], "openai-compatible")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_PROVIDER_NAME"], "MiniMax (China)")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_BASE_URL"], "https://api.minimaxi.com/v1")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_MODEL"], "MiniMax-M2.7-highspeed")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_API_KEY"], "sk-saved")
    }

    func testSubmitDraftMigratesLegacyKeychainProviderConfigurationWithoutRetypingKey() async {
        let store = StubSecretStore()
        store.secrets[ProviderSecrets.legacySelectedProviderAccount] = "minimax-china"
        store.secrets[ProviderSecrets.legacyProviderBaseURLAccount] = "https://api.minimaxi.com/v1"
        store.secrets[ProviderSecrets.legacyProviderModelAccount] = "MiniMax-M2.7-highspeed"
        store.secrets[ProviderSecrets.providerAPIKeyAccount] = "sk-legacy"
        let defaults = isolatedProviderDefaults()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: defaults
        )
        XCTAssertEqual(store.readAccounts, [])
        state.draft = "Hello Hermes"

        await state.submitDraft()

        XCTAssertEqual(state.selectedProvider, .minimaxChina)
        XCTAssertTrue(state.providerAPIKeyIsSaved)
        XCTAssertEqual(ProviderPreferences.selectedProvider(defaults: defaults), .minimaxChina)
        XCTAssertEqual(ProviderPreferences.providerBaseURL(defaults: defaults), "https://api.minimaxi.com/v1")
        XCTAssertEqual(ProviderPreferences.providerModel(defaults: defaults), "MiniMax-M2.7-highspeed")
        XCTAssertEqual(factory.environments.last?["HERMES_PROVIDER"], "openai-compatible")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_PROVIDER_NAME"], "MiniMax (China)")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_BASE_URL"], "https://api.minimaxi.com/v1")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_MODEL"], "MiniMax-M2.7-highspeed")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_API_KEY"], "sk-legacy")
    }

    func testSubmitDraftDoesNotFallBackToEchoWhenProviderKeyIsMissing() async {
        let store = StubSecretStore()
        let defaults = isolatedProviderDefaults()
        ProviderPreferences.save(
            provider: .minimaxChina,
            baseURL: "https://api.minimaxi.com/v1",
            model: "MiniMax-M2.7-highspeed",
            thinkingEnabled: false,
            reasoningEffort: "",
            defaults: defaults
        )
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: [.messageDelta(runId: "run_123", delta: "Hermes received: Hello")]
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: defaults
        )
        state.draft = "Hello"

        await state.submitDraft()

        XCTAssertEqual(factory.environments.last, [:])
        XCTAssertEqual(state.messages.last?.author, .system)
        XCTAssertEqual(state.messages.last?.text, "Provider is not configured. Save an API key or select Echo explicitly.")
    }

    func testTestingProviderConfigurationReportsSuccess() async {
        let runtimeClient = StubRuntimeClient(
            run: RuntimeRun(result: RunCreateResult(runId: "run_123", status: "running"), events: []),
            providerTestResult: ProviderTestResult(status: "ok", provider: "MiniMax (China)", model: "MiniMax-M2.7")
        )
        let state = AppState(runtimeClient: runtimeClient)

        await state.testProviderConfiguration()

        XCTAssertFalse(state.isTestingProvider)
        XCTAssertEqual(runtimeClient.providerTestCount, 1)
        XCTAssertEqual(state.providerStatusMessage, "MiniMax (China) MiniMax-M2.7 connection ok.")
    }

    func testTestingProviderConfigurationReportsFailure() async {
        let runtimeClient = StubRuntimeClient(
            run: RuntimeRun(result: RunCreateResult(runId: "run_123", status: "running"), events: []),
            providerTestError: ProcessRuntimeClientError.runtimeError(code: -32603, message: "HTTP 401 Unauthorized")
        )
        let state = AppState(runtimeClient: runtimeClient)

        await state.testProviderConfiguration()

        XCTAssertFalse(state.isTestingProvider)
        XCTAssertEqual(runtimeClient.providerTestCount, 1)
        XCTAssertEqual(state.providerStatusMessage, "Provider test failed: HTTP 401 Unauthorized")
    }

    func testSavingDeepSeekAPIKeyStoresSecretAndRebuildsRuntimeClientEnvironment() throws {
        let store = StubSecretStore()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: isolatedProviderDefaults()
        )
        state.deepSeekAPIKeyDraft = "  sk-deepseek-test  "

        try state.saveDeepSeekAPIKey()

        XCTAssertEqual(store.secrets[ProviderSecrets.deepSeekAPIKeyAccount], "sk-deepseek-test")
        XCTAssertEqual(state.deepSeekAPIKeyDraft, "")
        XCTAssertEqual(state.providerStatusMessage, "DeepSeek API key saved.")
        XCTAssertEqual(factory.environments.last?["HERMES_PROVIDER"], "openai-compatible")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_PROVIDER_NAME"], "DeepSeek V4 Pro")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_BASE_URL"], "https://api.deepseek.com")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_MODEL"], "deepseek-v4-pro")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_API_KEY"], "sk-deepseek-test")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_THINKING"], "enabled")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_REASONING_EFFORT"], "high")
    }

    func testInitImportsDeepSeekAPIKeyFromEnvironmentWhenKeychainIsEmpty() {
        let store = StubSecretStore()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))

        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            environment: ["DEEPSEEK_API_KEY": "  sk-from-env  "],
            providerDefaults: isolatedProviderDefaults()
        )

        XCTAssertEqual(store.secrets[ProviderSecrets.deepSeekAPIKeyAccount], "sk-from-env")
        XCTAssertEqual(state.providerStatusMessage, "DeepSeek API key imported from environment.")
        XCTAssertEqual(factory.environments.last, [:])
    }

    func testSavingOpenAICompatibleProviderStoresConfigAndRebuildsEnvironment() throws {
        let store = StubSecretStore()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: isolatedProviderDefaults()
        )
        state.selectedProvider = .openAICompatible
        state.providerBaseURLDraft = " https://api.example.com "
        state.providerModelDraft = " example-model "
        state.providerAPIKeyDraft = " sk-example "

        try state.saveProviderConfiguration()

        XCTAssertEqual(ProviderPreferences.selectedProvider(defaults: state.providerDefaults), .openAICompatible)
        XCTAssertEqual(ProviderPreferences.providerBaseURL(defaults: state.providerDefaults), "https://api.example.com")
        XCTAssertEqual(ProviderPreferences.providerModel(defaults: state.providerDefaults), "example-model")
        XCTAssertEqual(store.secrets[ProviderSecrets.openAICompatibleAPIKeyAccount], "sk-example")
        XCTAssertTrue(state.providerAPIKeyIsSaved)
        XCTAssertEqual(state.providerStatusMessage, "OpenAI-compatible provider saved.")
        XCTAssertEqual(factory.environments.last?["HERMES_PROVIDER"], "openai-compatible")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_PROVIDER_NAME"], "OpenAI-compatible")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_BASE_URL"], "https://api.example.com")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_MODEL"], "example-model")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_API_KEY"], "sk-example")
    }

    func testSavingProviderWithExistingKeyAllowsEmptyDraftAndKeepsStoredSecret() throws {
        let store = StubSecretStore()
        store.secrets[ProviderSecrets.providerAPIKeyAccount] = "sk-existing"
        let defaults = isolatedProviderDefaults()
        ProviderPreferences.saveAPIKeySaved(true, defaults: defaults)
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: defaults
        )
        state.selectedProvider = .minimaxChina
        state.providerBaseURLDraft = "https://api.minimaxi.com/v1"
        state.providerModelDraft = "MiniMax-M2.7-highspeed"
        state.providerAPIKeyDraft = ""

        try state.saveProviderConfiguration()

        XCTAssertEqual(store.secrets[ProviderSecrets.providerAPIKeyAccount], "sk-existing")
        XCTAssertEqual(factory.environments.last?["OPENAI_COMPATIBLE_API_KEY"], "sk-existing")
        XCTAssertEqual(state.providerStatusMessage, "MiniMax (China) provider saved.")
    }

    func testClearingProviderAPIKeyDeletesSecretAndSavedMarker() throws {
        let store = StubSecretStore()
        store.secrets[ProviderSecrets.providerAPIKeyAccount] = "sk-existing"
        let defaults = isolatedProviderDefaults()
        ProviderPreferences.saveAPIKeySaved(true, defaults: defaults)
        let state = AppState(secretStore: store, providerDefaults: defaults)

        try state.clearProviderAPIKey()

        XCTAssertNil(store.secrets[ProviderSecrets.providerAPIKeyAccount])
        XCTAssertFalse(state.providerAPIKeyIsSaved)
        XCTAssertFalse(ProviderPreferences.apiKeySaved(defaults: defaults))
        XCTAssertEqual(state.providerStatusMessage, "Provider API key cleared.")
    }

    func testSelectingEchoProviderClearsProviderEnvironment() throws {
        let store = StubSecretStore()
        let factory = RecordingRuntimeClientFactory(run: RuntimeRun(
            result: RunCreateResult(runId: "run_123", status: "running"),
            events: []
        ))
        let state = AppState(
            runtimeClientFactory: factory.makeClient(runtimeURL:extraEnvironment:),
            secretStore: store,
            providerDefaults: isolatedProviderDefaults()
        )
        state.selectedProvider = .echo

        try state.saveProviderConfiguration()

        XCTAssertEqual(ProviderPreferences.selectedProvider(defaults: state.providerDefaults), .echo)
        XCTAssertEqual(state.providerStatusMessage, "Echo provider selected.")
        XCTAssertEqual(factory.environments.last, [:])
    }

    func testProviderPresetsFillBaseURLAndDefaultModel() {
        let expected: [(ProviderSelection, String, String, Bool)] = [
            (.deepSeek, "https://api.deepseek.com", "deepseek-v4-pro", true),
            (.openAI, "https://api.openai.com/v1", "gpt-5.4", true),
            (.openRouter, "https://openrouter.ai/api/v1", "openrouter/auto", true),
            (.together, "https://api.together.xyz/v1", "meta-llama/Llama-3.3-70B-Instruct-Turbo", true),
            (.fireworks, "https://api.fireworks.ai/inference/v1", "accounts/fireworks/models/llama-v3p1-405b-instruct", true),
            (.groq, "https://api.groq.com/openai/v1", "llama-3.3-70b-versatile", true),
            (.moonshot, "https://api.moonshot.ai/v1", "kimi-k2.6", true),
            (.qwen, "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus", true),
            (.zhipu, "https://open.bigmodel.cn/api/paas/v4", "glm-4.5", true),
            (.minimax, "https://api.minimax.io/v1", "MiniMax-M2.7", true),
            (.minimaxChina, "https://api.minimaxi.com/v1", "MiniMax-M2.7", true),
            (.volcengineArk, "https://ark.cn-beijing.volces.com/api/v3", "doubao-seed-1-6-251015", true),
            (.ollama, "http://localhost:11434/v1", "llama3.3", false)
        ]

        for (provider, baseURL, model, requiresAPIKey) in expected {
            let preset = ProviderPreset.preset(for: provider)
            XCTAssertEqual(preset?.baseURL, baseURL)
            XCTAssertEqual(preset?.defaultModel, model)
            XCTAssertEqual(preset?.requiresAPIKey, requiresAPIKey)
        }
    }
}

private func isolatedProviderDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: "HermesAgentTests.\(UUID().uuidString)")!
    return defaults
}

private final class StubRuntimeClient: RuntimeClient {
    struct Request: Equatable {
        let sessionId: String
        let agentProfileId: String
        let input: String
        let history: [RunHistoryMessage]
        let workspacePath: String
    }

    private let run: RuntimeRun
    private let providerTestResult: ProviderTestResult
    private let providerTestError: Error?
    private(set) var requests: [Request] = []
    private(set) var providerTestCount = 0

    init(
        run: RuntimeRun,
        providerTestResult: ProviderTestResult = ProviderTestResult(status: "ok", provider: "Echo", model: "echo"),
        providerTestError: Error? = nil
    ) {
        self.run = run
        self.providerTestResult = providerTestResult
        self.providerTestError = providerTestError
    }

    func handshake() async throws -> RuntimeHandshakeResult {
        RuntimeHandshakeResult(
            protocolVersion: "0.1.0",
            runtime: RuntimeInfo(name: "stub-runtime", version: "0.1.0"),
            capabilities: ["runs"]
        )
    }

    func createRun(
        sessionId: String,
        agentProfileId: String,
        input: String,
        history: [RunHistoryMessage],
        workspacePath: String
    ) async throws -> RuntimeRun {
        requests.append(Request(
            sessionId: sessionId,
            agentProfileId: agentProfileId,
            input: input,
            history: history,
            workspacePath: workspacePath
        ))
        return run
    }

    func testProvider() async throws -> ProviderTestResult {
        providerTestCount += 1
        if let providerTestError {
            throw providerTestError
        }
        return providerTestResult
    }
}

private final class StubSecretStore: SecretStore {
    var secrets: [String: String] = [:]
    private(set) var readAccounts: [String] = []

    func setSecret(_ value: String, account: String) throws {
        secrets[account] = value
    }

    func getSecret(account: String) throws -> String? {
        readAccounts.append(account)
        return secrets[account]
    }

    func deleteSecret(account: String) throws {
        secrets.removeValue(forKey: account)
    }
}

private final class RecordingRuntimeClientFactory {
    private let run: RuntimeRun
    private(set) var environments: [[String: String]] = []

    init(run: RuntimeRun) {
        self.run = run
    }

    func makeClient(runtimeURL: URL, extraEnvironment: [String: String]) -> RuntimeClient {
        environments.append(extraEnvironment)
        return StubRuntimeClient(run: run)
    }
}
