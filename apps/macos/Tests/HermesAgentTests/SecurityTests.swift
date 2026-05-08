import Testing
import Foundation
@testable import HermesAgentCore

/// Tests that guard against malicious or unexpected input reaching sensitive code paths.
@Suite("Security")
struct SecurityTests {

    // MARK: - Env-file injection via newlines

    @Test("newline in API key value does not inject extra env entries")
    func newlineInValueDoesNotInject() throws {
        let env = tmpEnvFile()
        defer { try? FileManager.default.removeItem(atPath: env) }

        // A malicious key value containing a newline followed by another assignment
        let malicious = "legitimate-secret\nEVIL_KEY=injected"
        try HermesConfig.writeEnvKey("MY_KEY", value: malicious, envPath: env)

        let keys = HermesConfig.readConfiguredKeys(envPath: env)
        // The injected key must not appear as a separate env var
        #expect(keys["MY_KEY"] != nil)
        #expect(keys["EVIL_KEY"] == nil, "newline injection must be blocked — EVIL_KEY must not become its own entry")
    }

    @Test("carriage-return and CRLF in API key value are stripped")
    func crlfStripped() throws {
        let env = tmpEnvFile()
        defer { try? FileManager.default.removeItem(atPath: env) }

        try HermesConfig.writeEnvKey("K", value: "val\r\nBAD=x", envPath: env)
        let keys = HermesConfig.readConfiguredKeys(envPath: env)
        #expect(keys["BAD"] == nil)
        let stored = keys["K"] ?? ""
        #expect(!stored.contains("\r"))
        #expect(!stored.contains("\n"))
    }

    @Test("updating existing key with newline in value does not inject")
    func updateExistingKeyNewlineInjection() throws {
        let env = tmpEnvFile(content: "MY_KEY=old\n")
        defer { try? FileManager.default.removeItem(atPath: env) }

        try HermesConfig.writeEnvKey("MY_KEY", value: "new\nEVIL=bad", envPath: env)
        let keys = HermesConfig.readConfiguredKeys(envPath: env)
        #expect(keys["EVIL"] == nil, "newline injection in update must also be blocked")
    }

    // MARK: - FileNode workspace boundaries

    @Test("symlink in workspace tree does not cause crash or infinite loop")
    func symlinkInTree() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create a symlink pointing back to the parent (circular-ish)
        let link = tmp.appending(path: "selflink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp)

        // Should return without crashing (symlink appears as a directory entry)
        let roots = FileNode.loadRoots(at: tmp.path)
        // The symlink node exists but we never auto-expand it
        let symlinkNode = roots.first(where: { $0.name == "selflink" })
        // If it loaded, children should not be loaded yet (lazy)
        if let node = symlinkNode, node.isDirectory {
            #expect(!node.isLoaded)
        }
    }

    @Test("workspace path with special characters is handled safely")
    func specialCharsInPath() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create a subdirectory with spaces and unicode in name
        let special = tmp.appending(path: "my folder 你好")
        try FileManager.default.createDirectory(at: special, withIntermediateDirectories: true)
        try "data".write(to: special.appending(path: "file.txt"), atomically: true, encoding: .utf8)

        let roots = FileNode.loadRoots(at: tmp.path)
        let dir = roots.first(where: { $0.name == "my folder 你好" })
        #expect(dir != nil)
        dir?.loadChildrenIfNeeded()
        #expect(dir?.children.count == 1)
    }
}

// MARK: - Helpers

private func tmpEnvFile(content: String = "") -> String {
    let path = NSTemporaryDirectory() + "hermes-sec-\(UUID().uuidString).env"
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    return path
}

private func makeTempDir() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "HermesSecTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
