import Testing
import Foundation
@testable import HermesAgentCore

@Suite("ApprovalPrompt")
struct ApprovalPromptTests {

    @Test("option with kind containing 'reject' is identified as rejection")
    func rejectKind() {
        let opt = ApprovalPrompt.Option(id: "1", name: "Reject", kind: "reject")
        #expect(opt.kind.contains("reject"))
    }

    @Test("option with kind 'approve' does not contain 'reject'")
    func approveKind() {
        let opt = ApprovalPrompt.Option(id: "2", name: "Approve", kind: "approve")
        #expect(!opt.kind.contains("reject"))
    }

    @Test("option with kind 'reject_always' is identified as rejection")
    func rejectAlwaysKind() {
        let opt = ApprovalPrompt.Option(id: "3", name: "Reject Always", kind: "reject_always")
        #expect(opt.kind.contains("reject"))
    }

    @Test("filtering options by reject kind returns only reject options")
    func filterByRejectKind() {
        let prompt = ApprovalPrompt(
            id: "p1",
            toolCall: "some_tool",
            summary: "Do something",
            options: [
                ApprovalPrompt.Option(id: "a", name: "Yes", kind: "approve"),
                ApprovalPrompt.Option(id: "b", name: "No", kind: "reject"),
                ApprovalPrompt.Option(id: "c", name: "Never", kind: "reject_always"),
            ]
        )
        let rejectOptions = prompt.options.filter { $0.kind.contains("reject") }
        #expect(rejectOptions.count == 2)
        #expect(rejectOptions.allSatisfy { $0.kind.contains("reject") })
    }

    @Test("prompt equality is based on id")
    func promptEquality() {
        let opt = ApprovalPrompt.Option(id: "o1", name: "OK", kind: "approve")
        let p1 = ApprovalPrompt(id: "x", toolCall: "t", summary: "s", options: [opt])
        let p2 = ApprovalPrompt(id: "x", toolCall: "t", summary: "s", options: [opt])
        #expect(p1 == p2)
    }

    @Test("prompt with no options has empty options array")
    func emptyOptions() {
        let prompt = ApprovalPrompt(id: "p2", toolCall: "tool", summary: "desc", options: [])
        #expect(prompt.options.isEmpty)
    }
}
