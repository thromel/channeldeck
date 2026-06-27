import Foundation
import Security

enum KeychainService {
    private static let service = "com.channeldeck.credentials"

    static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            return
        }

        try? delete(account: account)

        let query = query(serviceName: service, account: account, returningData: false).merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, new in new }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    static func read(account: String) throws -> String? {
        try read(account: account, serviceName: service)
    }

    static func delete(account: String) throws {
        let status = SecItemDelete(query(serviceName: service, account: account, returningData: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func read(account: String, serviceName: String) throws -> String? {
        let query = query(serviceName: serviceName, account: account, returningData: true)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func query(serviceName: String, account: String, returningData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }

        return query
    }
}

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}
