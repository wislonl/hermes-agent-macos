import Foundation

protocol SecretStore {
    func setSecret(_ value: String, account: String) throws
    func getSecret(account: String) throws -> String?
    func deleteSecret(account: String) throws
}

enum KeychainStoreError: Error, Equatable {
    case unimplemented
}

struct KeychainStore: SecretStore {
    func setSecret(_ value: String, account: String) throws {
        throw KeychainStoreError.unimplemented
    }

    func getSecret(account: String) throws -> String? {
        throw KeychainStoreError.unimplemented
    }

    func deleteSecret(account: String) throws {
        throw KeychainStoreError.unimplemented
    }
}
