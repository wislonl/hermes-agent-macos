import XCTest
@testable import HermesAgent

final class AppStateTests: XCTestCase {
    func testSubmitDraftAddsUserMessageAndClearsDraft() {
        let state = AppState()
        state.draft = "Hello Hermes"

        state.submitDraft()

        XCTAssertEqual(state.messages.last?.text, "Hello Hermes")
        XCTAssertEqual(state.messages.last?.author, .user)
        XCTAssertEqual(state.draft, "")
    }
}
