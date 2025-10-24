import Foundation
import SwiftUI
import Combine

/// Notification posted when authentication state changes
extension Notification.Name {
    static let authenticationDidChange = Notification.Name("authenticationDidChange")
}

/// Centralized authentication manager to handle API key access and caching
/// Ensures keychain is accessed only once and state is available throughout the app
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()

    // Observable state for UI reactivity
    var isAuthenticated: Bool = false
    var apiKey: String?
    var isCheckingAuthentication: Bool = false
    var authenticationError: String?

    private let keychainService = KeychainService.shared

    private init() {
        // Don't check immediately - let the app explicitly call checkAuthentication()
    }

    /// Check authentication status by attempting to retrieve API key from keychain
    /// This should be called ONCE at app launch
    func checkAuthentication() async {
        await MainActor.run {
            isCheckingAuthentication = true
            authenticationError = nil
        }

        // Attempt to get API key from keychain (will prompt user if needed)
        if let key = keychainService.getAPIKey() {
            await MainActor.run {
                apiKey = key
                isAuthenticated = true
                isCheckingAuthentication = false
            }
            print("✅ AuthenticationManager: API key retrieved and cached")
        } else {
            await MainActor.run {
                apiKey = nil
                isAuthenticated = false
                isCheckingAuthentication = false
                authenticationError = "No API key found. Please add your OpenAI API key in Settings."
            }
            print("⚠️ AuthenticationManager: No API key found")
        }
    }

    /// Get the cached API key without accessing keychain again
    func getCachedAPIKey() -> String? {
        return apiKey
    }

    /// Save a new API key and update authentication state
    func saveAPIKey(_ key: String) -> Bool {
        let success = keychainService.saveAPIKey(key)

        if success {
            apiKey = key
            isAuthenticated = true
            authenticationError = nil
            print("✅ AuthenticationManager: API key saved and cached")

            // Post notification to trigger reinitialization of services
            NotificationCenter.default.post(name: .authenticationDidChange, object: nil)
        } else {
            authenticationError = "Failed to save API key to keychain"
            print("❌ AuthenticationManager: Failed to save API key")
        }

        return success
    }

    /// Remove API key and reset authentication state
    func removeAPIKey() -> Bool {
        let success = keychainService.deleteAPIKey()

        if success {
            apiKey = nil
            isAuthenticated = false
            authenticationError = nil
            print("✅ AuthenticationManager: API key removed")
        }

        return success
    }

    /// Invalidate cached credentials (force re-check)
    func invalidateCache() {
        apiKey = nil
        isAuthenticated = false
        keychainService.invalidateCache()
        print("⚠️ AuthenticationManager: Cache invalidated")
    }
}
