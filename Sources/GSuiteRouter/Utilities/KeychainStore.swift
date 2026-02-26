import Foundation
import Security

struct KeychainStore {
    let service: String

    func data(for key: String) -> Data? {
        var query: [String: Any] = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.operationFailed(status)
            }
        } else if status != errSecSuccess {
            throw KeychainError.operationFailed(status)
        }
    }

    func remove(_ key: String) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

enum KeychainError: Error, LocalizedError {
    case operationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error \(status)"
        }
    }
}
