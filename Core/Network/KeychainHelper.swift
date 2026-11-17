// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0 or GNU General Public License v3.0+.
// Ported from Amaze File Manager for iOS.

import Foundation
import Security

public struct KeychainHelper: Sendable {
    public static let shared = KeychainHelper()

    private let serviceName = "xyz.teamamaze.amazefilemanager.credentials"

    public init() {}

    /// Saves or updates a password in the iOS Keychain securely.
    @discardableResult
    public func savePassword(_ password: String, for account: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        // Query to check if existing
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return false
    }

    /// Retrieves a password from the iOS Keychain.
    public func getPassword(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data, let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    /// Deletes a password from the iOS Keychain.
    @discardableResult
    public func deletePassword(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
