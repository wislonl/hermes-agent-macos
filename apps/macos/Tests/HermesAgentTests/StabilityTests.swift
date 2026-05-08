import Testing
import Foundation
@testable import HermesAgentCore

/// Tests that the app degrades gracefully under unexpected filesystem and input conditions.
@Suite("Stability")
struct StabilityTests {

    // MARK: - FileNode edge cases

    @Test("loadRoots on non-existent path returns empty, no crash")
    func nonExistentPath() {
        let roots = FileNode.loadRoots(at: "/nonexistent/path/\(UUID().uuidString)")
        #expect(roots.isEmpty)
    }

    @Test("loadRoots on a file path (not a directory) returns empty")
    func filePathInsteadOfDirectory() throws {
        let tmp = NSTemporaryDirectory() + "hermes-stab-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try "content".write(toFile: tmp, atomically: true, encoding: .utf8)

        let roots = FileNode.loadRoots(at: tmp)
        #expect(roots.isEmpty)
    }

    @Test("loadRoots on empty directory returns empty")
    func emptyDirectory() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "hermes-stab-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let roots = FileNode.loadRoots(at: tmp.path)
        #expect(roots.isEmpty)
    }

    @Test("loadChildrenIfNeeded on non-existent directory returns empty children")
    func loadChildrenNonExistent() {
        let node = FileNode(url: URL(fileURLWithPath: "/does/not/exist"), isDirectory: true)
        node.loadChildrenIfNeeded()
        #expect(node.isLoaded)
        #expect(node.children.isEmpty)
    }

    @Test("repeated loadChildrenIfNeeded is idempotent")
    func loadChildrenIdempotent() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "hermes-stab-idem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "x".write(to: tmp.appending(path: "a.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let node = FileNode(url: tmp, isDirectory: true)
        node.loadChildrenIfNeeded()
        let countAfterFirst = node.children.count
        node.loadChildrenIfNeeded()  // second call — should be no-op
        #expect(node.children.count == countAfterFirst)
    }

    // MARK: - HermesConfig edge cases

    @Test("readConfiguredKeys on non-existent file returns empty dict")
    func readMissingEnvFile() {
        let missing = NSTemporaryDirectory() + "does-not-exist-\(UUID().uuidString).env"
        let keys = HermesConfig.readConfiguredKeys(envPath: missing)
        #expect(keys.isEmpty)
    }

    @Test("writeEnvKey to non-existent directory throws")
    func writeToMissingDirectory() {
        let badPath = "/nonexistent/dir/\(UUID().uuidString)/.env"
        #expect(throws: (any Error).self) {
            try HermesConfig.writeEnvKey("K", value: "v", envPath: badPath)
        }
    }

    @Test("removeEnvKey on non-existent file does not crash")
    func removeKeyMissingFile() throws {
        // When the file doesn't exist, removeEnvKey reads [] and writes an empty file — no crash or throw.
        let missing = NSTemporaryDirectory() + "missing-\(UUID().uuidString).env"
        defer { try? FileManager.default.removeItem(atPath: missing) }
        try HermesConfig.removeEnvKey("K", envPath: missing)
        let keys = HermesConfig.readConfiguredKeys(envPath: missing)
        #expect(keys.isEmpty)
    }

    @Test("readConfiguredKeys handles completely empty file")
    func emptyEnvFile() throws {
        let path = NSTemporaryDirectory() + "empty-\(UUID().uuidString).env"
        try "".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let keys = HermesConfig.readConfiguredKeys(envPath: path)
        #expect(keys.isEmpty)
    }

    // MARK: - AppState edge cases

    @Test("insertFileReference with empty workspacePath falls back to absolute")
    @MainActor func insertWithEmptyWorkspace() {
        let state = AppState(workspacePath: "")
        state.insertFileReference("/some/absolute/file.py")
        #expect(state.draft == "@/some/absolute/file.py")
    }

    @Test("insertFileReference called multiple times appends correctly")
    @MainActor func multipleInserts() {
        let state = AppState(workspacePath: "/proj")
        state.insertFileReference("/proj/a.swift")
        state.insertFileReference("/proj/b.swift")
        #expect(state.draft == "@a.swift @b.swift")
    }
}
