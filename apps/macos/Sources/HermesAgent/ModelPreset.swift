import Foundation

enum ProviderGroup: String, CaseIterable {
    case claude   = "Claude (Anthropic)"
    case openai   = "GPT / OpenAI"
    case gemini   = "Gemini (Google)"
    case deepseek = "DeepSeek"
    case grok     = "Grok (xAI)"
    case qwen     = "Qwen (Alibaba)"
    case kimi     = "Kimi (Moonshot)"
    case glm      = "GLM (ZhipuAI)"
    case minimax  = "MiniMax"
}

struct ModelPreset: Identifiable, Hashable {
    let id: String
    let displayName: String
    let group: ProviderGroup
    let provider: String        // hermes provider name in config.yaml
    let modelId: String         // model.default in config.yaml
    let envKey: String          // env var in ~/.hermes/.env
    let keyHint: String         // SecureField placeholder
    let validationURL: String?  // GET endpoint to test key; nil = skip
    let useQueryAuth: Bool      // true = ?key=KEY, false = Bearer token
}

extension ModelPreset {
    static let all: [ModelPreset] = [

        // ── Claude ────────────────────────────────────────────────────
        ModelPreset(
            id: "or-claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            group: .claude,
            provider: "openrouter",
            modelId: "anthropic/claude-sonnet-4-6",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-claude-opus-4-7",
            displayName: "Claude Opus 4.7",
            group: .claude,
            provider: "openrouter",
            modelId: "anthropic/claude-opus-4-7",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),

        // ── GPT / OpenAI ──────────────────────────────────────────────
        ModelPreset(
            id: "or-gpt-4-1",
            displayName: "GPT-4.1",
            group: .openai,
            provider: "openrouter",
            modelId: "openai/gpt-4.1",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-gpt-4o",
            displayName: "GPT-4o",
            group: .openai,
            provider: "openrouter",
            modelId: "openai/gpt-4o",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-gpt-5-mini",
            displayName: "GPT-5 Mini",
            group: .openai,
            provider: "openrouter",
            modelId: "openai/gpt-5-mini",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),

        // ── Gemini ────────────────────────────────────────────────────
        ModelPreset(
            id: "or-gemini-3-pro",
            displayName: "Gemini 3 Pro (via OpenRouter)",
            group: .gemini,
            provider: "openrouter",
            modelId: "google/gemini-3-pro-preview",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-gemini-3-flash",
            displayName: "Gemini 3 Flash (via OpenRouter)",
            group: .gemini,
            provider: "openrouter",
            modelId: "google/gemini-3-flash-preview",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "gemini-3-pro-direct",
            displayName: "Gemini 3 Pro (Google AI Studio)",
            group: .gemini,
            provider: "gemini",
            modelId: "gemini-3-pro-preview",
            envKey: "GOOGLE_API_KEY",
            keyHint: "AIza...",
            validationURL: "https://generativelanguage.googleapis.com/v1beta/models",
            useQueryAuth: true
        ),
        ModelPreset(
            id: "gemini-3-flash-direct",
            displayName: "Gemini 3 Flash (Google AI Studio)",
            group: .gemini,
            provider: "gemini",
            modelId: "gemini-3-flash-preview",
            envKey: "GOOGLE_API_KEY",
            keyHint: "AIza...",
            validationURL: "https://generativelanguage.googleapis.com/v1beta/models",
            useQueryAuth: true
        ),

        // ── DeepSeek ──────────────────────────────────────────────────
        ModelPreset(
            id: "or-deepseek-v4-pro",
            displayName: "DeepSeek V4 Pro",
            group: .deepseek,
            provider: "openrouter",
            modelId: "deepseek/deepseek-v4-pro",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-deepseek-v4-flash",
            displayName: "DeepSeek V4 Flash",
            group: .deepseek,
            provider: "openrouter",
            modelId: "deepseek/deepseek-v4-flash",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "or-deepseek-r1",
            displayName: "DeepSeek R1-0528",
            group: .deepseek,
            provider: "openrouter",
            modelId: "deepseek-ai/DeepSeek-R1-0528",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),

        // ── Grok ──────────────────────────────────────────────────────
        ModelPreset(
            id: "or-grok-4",
            displayName: "Grok 4 Reasoning",
            group: .grok,
            provider: "openrouter",
            modelId: "x-ai/grok-4-1-fast-reasoning",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),

        // ── Qwen ──────────────────────────────────────────────────────
        ModelPreset(
            id: "or-qwen-36-plus",
            displayName: "Qwen 3.6 Plus",
            group: .qwen,
            provider: "openrouter",
            modelId: "alibaba/qwen3.6-plus",
            envKey: "OPENROUTER_API_KEY",
            keyHint: "sk-or-v1-...",
            validationURL: "https://openrouter.ai/api/v1/auth/key",
            useQueryAuth: false
        ),

        // ── Kimi ──────────────────────────────────────────────────────
        ModelPreset(
            id: "kimi-k2",
            displayName: "Kimi K2.5",
            group: .kimi,
            provider: "kimi",
            modelId: "kimi-k2.5",
            envKey: "KIMI_API_KEY",
            keyHint: "sk-kimi-...",
            validationURL: "https://api.kimi.com/coding/v1/models",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "kimi-grok-code",
            displayName: "Grok Code Fast (Kimi)",
            group: .kimi,
            provider: "kimi",
            modelId: "grok-code-fast-1",
            envKey: "KIMI_API_KEY",
            keyHint: "sk-kimi-...",
            validationURL: "https://api.kimi.com/coding/v1/models",
            useQueryAuth: false
        ),

        // ── GLM ───────────────────────────────────────────────────────
        ModelPreset(
            id: "glm-51",
            displayName: "GLM-5.1",
            group: .glm,
            provider: "zhipu",
            modelId: "glm-5.1",
            envKey: "GLM_API_KEY",
            keyHint: "...",
            validationURL: "https://open.bigmodel.cn/api/paas/v4/models",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "glm-5-turbo",
            displayName: "GLM-5 Turbo",
            group: .glm,
            provider: "zhipu",
            modelId: "glm-5-turbo",
            envKey: "GLM_API_KEY",
            keyHint: "...",
            validationURL: "https://open.bigmodel.cn/api/paas/v4/models",
            useQueryAuth: false
        ),

        // ── MiniMax ───────────────────────────────────────────────────
        ModelPreset(
            id: "minimax-m27",
            displayName: "MiniMax M2.7 (国际)",
            group: .minimax,
            provider: "minimax",
            modelId: "MiniMax-M2.7",
            envKey: "MINIMAX_API_KEY",
            keyHint: "sk-...",
            validationURL: "https://api.minimax.io/v1/models",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "minimax-m27-cn",
            displayName: "MiniMax M2.7 (中国节点)",
            group: .minimax,
            provider: "minimax-cn",
            modelId: "MiniMax-M2.7",
            envKey: "MINIMAX_CN_API_KEY",
            keyHint: "sk-cp-...",
            validationURL: "https://api.minimaxi.com/v1/models",
            useQueryAuth: false
        ),
        ModelPreset(
            id: "minimax-m25",
            displayName: "MiniMax M2.5",
            group: .minimax,
            provider: "minimax",
            modelId: "MiniMax-M2.5",
            envKey: "MINIMAX_API_KEY",
            keyHint: "sk-...",
            validationURL: "https://api.minimax.io/v1/models",
            useQueryAuth: false
        ),
    ]

    static func presets(for group: ProviderGroup) -> [ModelPreset] {
        all.filter { $0.group == group }
    }
}
