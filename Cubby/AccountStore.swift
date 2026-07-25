//
//  AccountStore.swift
//  Cubby
//
//  Stores the server URL + access token in the Keychain.
//

import Foundation
import Security

struct Account: Codable, Equatable {
    var serverURL: String
    var token: String

    var url: URL? { URL(string: serverURL) }
    var host: String { URL(string: serverURL)?.host ?? serverURL }
}

enum AccountStore {
    private static let service = "xyz.gramajo.cubby"
    private static let key = "account"

    static func load() -> Account? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let account = try? JSONDecoder().decode(Account.self, from: data)
        else { return nil }
        return account
    }

    static func save(_ account: Account) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
