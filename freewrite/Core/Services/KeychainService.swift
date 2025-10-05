import Foundation
import Security

class KeychainService: APIKeyStorageProtocol {
    static let shared = KeychainService()
    
    private let service = "com.lifeos.freewrite"
    private let account = "openai-api-key"
    private var cachedKeyExists: Bool?
    
    private init() {}
    
    func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        // Create access control that allows user to choose "Always Allow"
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlocked,
            [],  // No additional constraints - allows "Always Allow" option
            nil
        ) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item with access control
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            cachedKeyExists = true
        }
        
        return status == errSecSuccess
    }
    
    func getAPIKey() -> String? {
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
        
        // Trim whitespace as defensive measure
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            cachedKeyExists = false
        }
        
        return status == errSecSuccess
    }
    
    func hasAPIKey() -> Bool {
        // Use cached value if available to avoid repeated keychain access
        if let cached = cachedKeyExists {
            return cached
        }
        
        // Check keychain and cache the result
        let exists = getAPIKey() != nil
        cachedKeyExists = exists
        return exists
    }
    
    func invalidateCache() {
        cachedKeyExists = nil
    }
}
