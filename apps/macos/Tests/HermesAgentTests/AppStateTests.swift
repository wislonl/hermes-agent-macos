import Testing
import Foundation
@testable import HermesAgentCore

@Suite("AppState")
struct AppStateTests {

    // MARK: - insertFileReference

    @Test("inserts relative path with @ prefix")
    @MainActor func insertsRelativePath() {
        let state = AppState(workspacePath: "/Users/alice/myproject")
        state.insertFileReference("/Users/alice/myproject/src/main.swift")
        #expect(state.draft == "@src/main.swift")
    }

    @Test("appends to existing draft with space")
    @MainActor func appendsToDraft() {
        let state = AppState(workspacePath: "/proj")
        state.draft = "look at"
        state.insertFileReference("/proj/foo.py")
        #expect(state.draft == "look at @foo.py")
    }

    @Test("falls back to absolute path when outside workspace")
    @MainActor func fallsBackToAbsolute() {
        let state = AppState(workspacePath: "/proj")
        state.insertFileReference("/other/place/file.txt")
        #expect(state.draft == "@/other/place/file.txt")
    }

    @Test("handles nested paths correctly")
    @MainActor func handlesNestedPaths() {
        let state = AppState(workspacePath: "/a/b")
        state.insertFileReference("/a/b/c/d/e.ts")
        #expect(state.draft == "@c/d/e.ts")
    }

    // MARK: - defaultWorkspacePath

    @Test("defaultWorkspacePath never returns '/'")
    func defaultWorkspacePathNotRoot() {
        let path = AppState.defaultWorkspacePath
        #expect(path != "/")
        #expect(!path.isEmpty)
    }
}
