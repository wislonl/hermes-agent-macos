import Testing
@testable import HermesAgentCore

@Suite("ModelPreset")
struct ModelPresetTests {

    @Test("all presets have non-empty required fields")
    func allPresetsValid() {
        for preset in ModelPreset.all {
            #expect(!preset.id.isEmpty,          "id empty: \(preset.displayName)")
            #expect(!preset.displayName.isEmpty,  "displayName empty: \(preset.id)")
            #expect(!preset.provider.isEmpty,     "provider empty: \(preset.id)")
            #expect(!preset.modelId.isEmpty,      "modelId empty: \(preset.id)")
            #expect(!preset.envKey.isEmpty,       "envKey empty: \(preset.id)")
        }
    }

    @Test("all preset ids are unique")
    func uniqueIds() {
        let ids = ModelPreset.all.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count)
    }

    @Test("presets(for:) returns only matching group")
    func presetsForGroup() {
        let claudeDirect = ModelPreset.presets(for: .anthropicDirect)
        #expect(!claudeDirect.isEmpty)
        for p in claudeDirect {
            #expect(p.group == .anthropicDirect)
            #expect(p.provider == "anthropic")
            #expect(p.envKey == "ANTHROPIC_TOKEN")
        }
    }

    @Test("Anthropic direct presets have nil validationURL")
    func anthropicDirectHasNoValidationURL() {
        for preset in ModelPreset.presets(for: .anthropicDirect) {
            #expect(preset.validationURL == nil, "expected nil validationURL for \(preset.id)")
        }
    }

    @Test("OpenRouter presets use Bearer auth")
    func openRouterPresetsUseBearerAuth() {
        let orPresets = ModelPreset.all.filter { $0.envKey == "OPENROUTER_API_KEY" }
        #expect(!orPresets.isEmpty)
        for p in orPresets {
            #expect(!p.useQueryAuth, "\(p.id) should use Bearer not query auth")
            #expect(p.provider == "openrouter")
        }
    }

    @Test("Gemini direct presets use query auth")
    func geminiUsesQueryAuth() {
        let geminiDirect = ModelPreset.all.filter { $0.envKey == "GOOGLE_API_KEY" }
        for p in geminiDirect {
            #expect(p.useQueryAuth, "\(p.id) should use query auth")
        }
    }

    @Test("all ProviderGroup cases have at least one preset")
    func everyGroupHasPresets() {
        for group in ProviderGroup.allCases {
            let count = ModelPreset.presets(for: group).count
            #expect(count > 0, "group '\(group.rawValue)' has no presets")
        }
    }
}
