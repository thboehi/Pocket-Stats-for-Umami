import Foundation
import Security

/// Keychain storage for secrets, shared between the app and the widget through
/// the App Group (an App Group identifier is a valid keychain access group).
enum CredentialStore {
    enum Secret: String {
        case password, token, apiKey
    }

    private static let service = "ch.thbo.analyticsforumami"

    static func get(_ secret: Secret, for accountID: UUID) -> String? {
        var query = baseQuery(secret, accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, _ secret: Secret, for accountID: UUID) {
        guard let value else {
            delete(secret, for: accountID)
            return
        }
        var query = baseQuery(secret, accountID)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            // The widget refreshes in the background, after the first unlock.
            // Secrets never leave this device (not in backups restored elsewhere).
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }
        if status == errSecItemNotFound {
            query.merge(attributes) { $1 }
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func delete(_ secret: Secret, for accountID: UUID) {
        var query = baseQuery(secret, accountID)
        if SecItemDelete(query as CFDictionary) == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            SecItemDelete(query as CFDictionary)
        }
    }

    static func deleteAll(for accountID: UUID) {
        for secret in [Secret.password, .token, .apiKey] {
            delete(secret, for: accountID)
        }
    }

    private static func baseQuery(_ secret: Secret, _ accountID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountID.uuidString).\(secret.rawValue)",
            kSecAttrAccessGroup as String: AppGroup.identifier,
        ]
    }
}
