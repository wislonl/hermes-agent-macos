import Testing
import Foundation
@testable import HermesAgentCore

@Suite("Models")
struct ModelsTests {

    // MARK: - String.strippingHermesMarkup

    @Test("strips complete think block")
    func stripsCompleteThinkBlock() {
        let raw = "<think>internal reasoning</think>Final answer"
        #expect(raw.strippingHermesMarkup() == "Final answer")
    }

    @Test("strips unclosed think block")
    func stripsUnclosedThinkBlock() {
        let raw = "<think>still thinking..."
        #expect(raw.strippingHermesMarkup() == "")
    }

    @Test("strips minimax tool-call XML")
    func stripsMiniMaxToolCall() {
        let raw = "text<minimax:tool_call>data</minimax:tool_call>more"
        #expect(raw.strippingHermesMarkup() == "textmore")
    }

    @Test("returns trimmed plain text unchanged")
    func plainTextUnchanged() {
        #expect("hello world".strippingHermesMarkup() == "hello world")
    }

    // MARK: - SessionSummary.displayTitle

    @Test("displayTitle extracts text after closing think tag")
    func displayTitleAfterThinkClose() {
        let s = SessionSummary(id: "1", title: "<think>internal</think>Visible title", cwd: "/", updatedAt: nil)
        #expect(s.displayTitle == "Visible title")
    }

    @Test("displayTitle extracts text inside open think tag")
    func displayTitleInsideOpenThink() {
        let s = SessionSummary(id: "1", title: "<think>Inside content", cwd: "/", updatedAt: nil)
        #expect(s.displayTitle == "Inside content")
    }

    @Test("displayTitle falls back to id prefix for empty title")
    func displayTitleFallbackToId() {
        let s = SessionSummary(id: "abcd1234efgh", title: "", cwd: "/", updatedAt: nil)
        #expect(s.displayTitle == "Session abcd1234")
    }

    // MARK: - SessionSummary.displayCwd

    @Test("displayCwd replaces home with ~")
    func displayCwdReplacesHome() {
        let home = NSHomeDirectory()
        let s = SessionSummary(id: "1", title: "t", cwd: home + "/projects/foo", updatedAt: nil)
        #expect(s.displayCwd == "~/projects/foo")
    }

    @Test("displayCwd shows ~ for root")
    func displayCwdRoot() {
        let s = SessionSummary(id: "1", title: "t", cwd: "/", updatedAt: nil)
        #expect(s.displayCwd == "~")
    }

    // MARK: - Additional strippingHermesMarkup edge cases

    @Test("strips multiple think blocks")
    func stripsMultipleThinkBlocks() {
        let raw = "<think>a</think>mid<think>b</think>end"
        #expect(raw.strippingHermesMarkup() == "midend")
    }

    @Test("whitespace-only result returns empty after trimming")
    func whitespaceOnlyResult() {
        let raw = "<think>reasoning</think>   "
        #expect(raw.strippingHermesMarkup() == "")
    }

    @Test("empty string returns empty")
    func emptyStringUnchanged() {
        #expect("".strippingHermesMarkup() == "")
    }

    // MARK: - Additional SessionSummary edge cases

    @Test("displayTitle with whitespace-only inside think returns fallback")
    func displayTitleWhitespaceInsideThink() {
        let s = SessionSummary(id: "zzzz5555aaaa", title: "<think>   </think>", cwd: "/", updatedAt: nil)
        #expect(s.displayTitle == "Session zzzz5555")
    }

    @Test("displayTitle with text after whitespace-padded think close")
    func displayTitleTextAfterWhitespacedClose() {
        let s = SessionSummary(id: "1", title: "<think>x</think>  Real Title  ", cwd: "/", updatedAt: nil)
        #expect(s.displayTitle == "Real Title")
    }
}
