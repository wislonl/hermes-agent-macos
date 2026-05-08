import Testing
import Foundation
@testable import HermesAgentCore

@Suite("HermesConfig")
struct HermesConfigTests {

    // MARK: - maskedKey

    @Test("masks key leaving last 4 visible")
    func masksKey() {
        #expect(HermesConfig.maskedKey("sk-or-v1-abcdefgh") == "••••efgh")
    }

    @Test("fully masks short keys (≤8 chars)")
    func masksShortKey() {
        #expect(HermesConfig.maskedKey("abc") == "•••")
        #expect(HermesConfig.maskedKey("12345678") == "••••••••")  // exactly 8 → all masked
        #expect(HermesConfig.maskedKey("123456789") == "••••6789") // 9 chars → shows last 4
    }

    // MARK: - .env read / write

    @Test("writeEnvKey appends new key")
    func appendsNewKey() throws {
        let env = tmpEnvFile()
        defer { try? FileManager.default.removeItem(atPath: env) }

        try withEnv(path: env) {
            try HermesConfig.writeEnvKey("MY_KEY", value: "abc123", envPath: env)
            let keys = HermesConfig.readConfiguredKeys(envPath: env)
            #expect(keys["MY_KEY"] == "abc123")
        }
    }

    @Test("writeEnvKey updates existing key")
    func updatesExistingKey() throws {
        let env = tmpEnvFile(content: "MY_KEY=old\n")
        defer { try? FileManager.default.removeItem(atPath: env) }

        try withEnv(path: env) {
            try HermesConfig.writeEnvKey("MY_KEY", value: "new", envPath: env)
            let keys = HermesConfig.readConfiguredKeys(envPath: env)
            #expect(keys["MY_KEY"] == "new")
        }
    }

    @Test("removeEnvKey comments out the line")
    func removesKey() throws {
        let env = tmpEnvFile(content: "MY_KEY=secret\n")
        defer { try? FileManager.default.removeItem(atPath: env) }

        try withEnv(path: env) {
            try HermesConfig.removeEnvKey("MY_KEY", envPath: env)
            let keys = HermesConfig.readConfiguredKeys(envPath: env)
            #expect(keys["MY_KEY"] == nil)
            let raw = try String(contentsOfFile: env, encoding: .utf8)
            #expect(raw.contains("# MY_KEY=secret"))
        }
    }

    @Test("readConfiguredKeys skips commented and empty lines")
    func skipsCommentedLines() throws {
        let content = """
        # IGNORED=yes
        ACTIVE=hello
        EMPTY=
        ANOTHER=world
        """
        let env = tmpEnvFile(content: content)
        defer { try? FileManager.default.removeItem(atPath: env) }

        let keys = HermesConfig.readConfiguredKeys(envPath: env)
        #expect(keys["ACTIVE"] == "hello")
        #expect(keys["ANOTHER"] == "world")
        #expect(keys["IGNORED"] == nil)
        #expect(keys["EMPTY"] == nil)
    }

    @Test("value with = signs is preserved intact")
    func preservesEqualsInValue() throws {
        let env = tmpEnvFile(content: "TOKEN=abc=def=ghi\n")
        defer { try? FileManager.default.removeItem(atPath: env) }

        let keys = HermesConfig.readConfiguredKeys(envPath: env)
        #expect(keys["TOKEN"] == "abc=def=ghi")
    }
}

// MARK: - Helpers

private func tmpEnvFile(content: String = "") -> String {
    let path = NSTemporaryDirectory() + "hermes-test-\(UUID().uuidString).env"
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    return path
}

private func withEnv(path: String, _ body: () throws -> Void) rethrows {
    try body()
}
