import Foundation
import Security
import CryptoKit

class KeychainService: APIKeyStorageProtocol {
    static let shared = KeychainService()

    private let service = "com.lifeos.freewrite"
    private let account = "openai-api-key"
    private let encryptionKeyAccount = "file-encryption-key"
    private var cachedKey: String?
    private var cachedEncryptionKey: SymmetricKey?

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

    func saveEncryptionKey(_ key: SymmetricKey) -> Bool {
        let keyData = EncryptionService.shared.keyToData(key)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecSuccess {
            cachedEncryptionKey = key
        }

        return status == errSecSuccess
    }

    func getOrCreateEncryptionKey() -> SymmetricKey? {
        if let cached = cachedEncryptionKey {
            return cached
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            let key = EncryptionService.shared.dataToKey(keyData)
            cachedEncryptionKey = key
            return key
        }

        print("No encryption key found, generating new key...")
        let newKey = EncryptionService.shared.generateEncryptionKey()

        if saveEncryptionKey(newKey) {
            print("Successfully generated and saved new encryption key")
            return newKey
        } else {
            print("Error: Failed to save new encryption key")
            return nil
        }
    }

    func hasEncryptionKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }

    func deleteEncryptionKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            cachedEncryptionKey = nil
        }

        return status == errSecSuccess
    }
}
