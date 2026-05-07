import Foundation

protocol SecretStore {
    func setSecret(_ secret: String, forKey key: String) throws
    func secret(forKey key: String) throws -> String?
    func deleteSecret(forKey key: String) throws
}

enum KeychainStoreError: Error, Equatable {
    case unimplemented
}

struct KeychainStore: SecretStore {
    func setSecret(_ secret: String, forKey key: String) throws {
        throw KeychainStoreError.unimplemented
    }

    func secret(forKey key: String) throws -> String? {
        throw KeychainStoreError.unimplemented
    }

    func deleteSecret(forKey key: String) throws {
        throw KeychainStoreError.unimplemented
    }
}
