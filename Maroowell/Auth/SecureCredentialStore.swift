import Foundation
import Security

struct SavedCredentials: Codable {
    var email: String = ""
    var password: String = ""
    var rememberEmail: Bool = false
    var rememberPassword: Bool = false
}

final class SecureCredentialStore {
    private let service = "com.maroowell.app.savedCredentials"
    private let account = "primary"

    func load() -> SavedCredentials {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode(SavedCredentials.self, from: data)
        else {
            return SavedCredentials()
        }

        var value = decoded
        if !value.rememberEmail {
            value.email = ""
            value.password = ""
            value.rememberPassword = false
        } else if !value.rememberPassword {
            value.password = ""
        }
        return value
    }

    func save(email: String, password: String, rememberEmail: Bool, rememberPassword: Bool) {
        guard rememberEmail else {
            clear()
            return
        }

        let savePassword = rememberPassword && !password.isEmpty
        let value = SavedCredentials(
            email: email,
            password: savePassword ? password : "",
            rememberEmail: true,
            rememberPassword: savePassword
        )
        guard let data = try? JSONEncoder().encode(value) else { return }

        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
