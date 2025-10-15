import Foundation
import Security

class KeychainService: APIKeyStorageProtocol {
    static let shared = KeychainService()
    
    private let service = "com.lifeos.freewrite"
    private let account = "openai-api-key"
    private var cachedKey: String?

    private init() {}
    
    func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecSuccess {
            cachedKey = key
        }

        return status == errSecSuccess
    }
    
    func getAPIKey() -> String? {
        if let cached = cachedKey {
            return cached
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        cachedKey = trimmedKey

        return trimmedKey
    }
    
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            cachedKey = nil
        }

        return status == errSecSuccess
    }
    
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }

    func invalidateCache() {
        cachedKey = nil
    }
}
