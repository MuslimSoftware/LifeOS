import Foundation
import CryptoKit

class EncryptionService {
    static let shared = EncryptionService()

    private init() {}

    func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    func keyToData(_ key: SymmetricKey) -> Data {
        return key.withUnsafeBytes { Data($0) }
    }

    func dataToKey(_ data: Data) -> SymmetricKey {
        return SymmetricKey(data: data)
    }

    func encrypt(_ plaintext: String, with key: SymmetricKey) -> Data? {
        guard let data = plaintext.data(using: .utf8) else {
            print("Error: Could not convert plaintext to data")
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                print("Error: Could not create combined sealed box")
                return nil
            }
            return combined
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }

    func decrypt(_ encryptedData: Data, with key: SymmetricKey) -> String? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
                print("Error: Could not convert decrypted data to string")
                return nil
            }

            return plaintext
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}
