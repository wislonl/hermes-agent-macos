import XCTest
@testable import HermesAgent

final class AppStateTests: XCTestCase {
    func testSubmitDraftAddsUserMessageAndClearsDraft() {
        let state = AppState()
        state.draft = "Hello Hermes"

        state.submitDraft()

        XCTAssertEqual(state.messages.suffix(2).first?.text, "Hello Hermes")
        XCTAssertEqual(state.messages.suffix(2).first?.author, .user)
        XCTAssertEqual(state.draft, "")
    }
}
