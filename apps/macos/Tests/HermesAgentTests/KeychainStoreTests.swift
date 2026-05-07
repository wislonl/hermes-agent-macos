import XCTest
@testable import HermesAgent

final class KeychainStoreTests: XCTestCase {
    func testKeychainRoundTrip() throws {
        let store = KeychainStore()
        let account = "test-\(UUID().uuidString)"

        try store.setSecret("sk-test-value", account: account)
        XCTAssertEqual(try store.getSecret(account: account), "sk-test-value")

        try store.deleteSecret(account: account)
        XCTAssertNil(try store.getSecret(account: account))
    }

    func testMissingSecretReturnsNil() throws {
        let store = KeychainStore()
        let account = "missing-\(UUID().uuidString)"

        XCTAssertNil(try store.getSecret(account: account))
    }

    func testSetSecretReplacesExistingValue() throws {
        let store = KeychainStore()
        let account = "replace-\(UUID().uuidString)"

        try store.setSecret("first", account: account)
        try store.setSecret("second", account: account)

        XCTAssertEqual(try store.getSecret(account: account), "second")
        try store.deleteSecret(account: account)
    }
}
