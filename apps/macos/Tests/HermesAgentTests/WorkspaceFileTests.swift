import Testing
import Foundation
@testable import HermesAgentCore

@Suite("FileNode")
struct WorkspaceFileTests {

    // MARK: - loadRoots

    @Test("loads only first level")
    func loadsOnlyFirstLevel() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try FileManager.default.createDirectory(at: tmp.appending(path: "subdir"), withIntermediateDirectories: true)
        try "x".write(to: tmp.appending(path: "subdir/deep.txt"), atomically: true, encoding: .utf8)
        try "y".write(to: tmp.appending(path: "top.txt"), atomically: true, encoding: .utf8)

        let roots = FileNode.loadRoots(at: tmp.path)
        #expect(roots.count == 2)

        let dir = try #require(roots.first(where: { $0.isDirectory }))
        // Children not loaded yet — lazy
        #expect(dir.children.isEmpty)
        #expect(!dir.isLoaded)
    }

    @Test("lazy loads on demand")
    func lazyLoads() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let sub = tmp.appending(path: "sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "content".write(to: sub.appending(path: "file.swift"), atomically: true, encoding: .utf8)

        let roots = FileNode.loadRoots(at: tmp.path)
        let dir = try #require(roots.first(where: { $0.isDirectory }))
        #expect(dir.children.isEmpty)

        dir.loadChildrenIfNeeded()
        #expect(dir.children.count == 1)
        #expect(dir.children[0].name == "file.swift")
        #expect(dir.isLoaded)

        // Second call is a no-op
        dir.loadChildrenIfNeeded()
        #expect(dir.children.count == 1)
    }

    @Test("skips hidden and junk directories")
    func skipsJunkNames() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        for name in [".git", "node_modules", "__pycache__", "venv", "keepme"] {
            try FileManager.default.createDirectory(
                at: tmp.appending(path: name),
                withIntermediateDirectories: true
            )
        }

        let roots = FileNode.loadRoots(at: tmp.path)
        let names = Set(roots.map(\.name))
        #expect(names == ["keepme"])
    }

    @Test("sorts directories before files, then alphabetically")
    func sortOrder() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try "".write(to: tmp.appending(path: "zebra.txt"), atomically: true, encoding: .utf8)
        try "".write(to: tmp.appending(path: "apple.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: tmp.appending(path: "mydir"), withIntermediateDirectories: true)

        let roots = FileNode.loadRoots(at: tmp.path)
        #expect(roots[0].name == "mydir")
        #expect(roots[1].name == "apple.txt")
        #expect(roots[2].name == "zebra.txt")
    }

    @Test("id is the resolved absolute path")
    func idIsAbsolutePath() throws {
        let tmp = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "x".write(to: tmp.appending(path: "f.txt"), atomically: true, encoding: .utf8)

        let roots = FileNode.loadRoots(at: tmp.path)
        let file = try #require(roots.first)
        // Resolve both sides: macOS /var/… is a symlink to /private/var/…
        let resolvedId = URL(fileURLWithPath: file.id).resolvingSymlinksInPath().path
        let resolvedExpected = tmp.resolvingSymlinksInPath().appending(path: "f.txt").path
        #expect(resolvedId == resolvedExpected)
    }
}

// MARK: - Helpers

private func makeTempDir() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "HermesTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
