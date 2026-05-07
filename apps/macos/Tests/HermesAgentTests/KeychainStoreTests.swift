import XCTest
@testable import HermesAgent

final class KeychainStoreTests: XCTestCase {
    func testSetSecretThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.setSecret("token", forKey: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }

    func testSecretForKeyThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.secret(forKey: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }

    func testDeleteSecretThrowsUnimplemented() {
        let store = KeychainStore()

        XCTAssertThrowsError(try store.deleteSecret(forKey: "OPENAI_API_KEY")) { error in
            XCTAssertEqual(error as? KeychainStoreError, .unimplemented)
        }
    }
}
