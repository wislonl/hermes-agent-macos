import XCTest
@testable import HermesAgent

final class KeychainStoreTests: XCTestCase {
    func testSetSecretThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.setSecret("token", account: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }

    func testGetSecretThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.getSecret(account: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }

    func testDeleteSecretThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.deleteSecret(account: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }
}
