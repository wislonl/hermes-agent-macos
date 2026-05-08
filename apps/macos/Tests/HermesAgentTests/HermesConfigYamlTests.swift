import Testing
import Foundation
@testable import HermesAgentCore

@Suite("HermesConfigYaml")
struct HermesConfigYamlTests {

    @Test("creates new config file with model and provider")
    func createsNewFile() throws {
        let path = tmpConfigPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        try HermesConfig.writeConfigModel(modelId: "gpt-4o", provider: "openai", configPath: path)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.contains("default: gpt-4o"))
        #expect(content.contains("provider: openai"))
    }

    @Test("updates existing default and provider lines")
    func updatesExistingLines() throws {
        let path = tmpConfigPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let initial = "model:\n  default: old-model\n  provider: old-provider\n"
        try initial.write(toFile: path, atomically: true, encoding: .utf8)

        try HermesConfig.writeConfigModel(modelId: "claude-3", provider: "anthropic", configPath: path)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.contains("default: claude-3"))
        #expect(content.contains("provider: anthropic"))
        #expect(!content.contains("old-model"))
        #expect(!content.contains("old-provider"))
    }

    @Test("creates directory if missing")
    func createsDirectory() throws {
        let dir = NSTemporaryDirectory() + "hermes-yaml-\(UUID().uuidString)"
        let path = dir + "/config.yaml"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try HermesConfig.writeConfigModel(modelId: "m", provider: "p", configPath: path)

        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("config without model section gets lines appended")
    func appendsToConfigWithoutModelSection() throws {
        let path = tmpConfigPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let initial = "logging:\n  level: debug\n"
        try initial.write(toFile: path, atomically: true, encoding: .utf8)

        try HermesConfig.writeConfigModel(modelId: "m1", provider: "prov", configPath: path)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.contains("default: m1"))
        #expect(content.contains("provider: prov"))
    }

    @Test("round-trip: write then read back matches")
    func roundTrip() throws {
        let path = tmpConfigPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        try HermesConfig.writeConfigModel(modelId: "test-model", provider: "test-provider", configPath: path)
        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.contains("test-model"))
        #expect(content.contains("test-provider"))
    }
}

private func tmpConfigPath() -> String {
    NSTemporaryDirectory() + "hermes-cfg-\(UUID().uuidString).yaml"
}
