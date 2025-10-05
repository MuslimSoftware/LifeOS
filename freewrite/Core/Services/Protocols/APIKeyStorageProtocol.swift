import Foundation

protocol APIKeyStorageProtocol {
    func saveAPIKey(_ key: String) -> Bool
    func getAPIKey() -> String?
    func deleteAPIKey() -> Bool
    func hasAPIKey() -> Bool
}
