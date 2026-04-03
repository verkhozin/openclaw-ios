import Foundation
import Security

/// Keychain wrapper for storing gateway credentials securely.
///
/// Stores: gatewayURL, authToken, deviceToken, deviceId
enum KeychainService {
    private static let service = "com.clios.app"
    
    // MARK: - CRUD
    
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing first
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Convenience
    
    /// Delete pairing-related keychain items.
    /// NOTE: Does NOT delete "deviceSigningKey" — that must persist across unpair/repair cycles.
    static func deleteAll() {
        let keys = ["gatewayURL", "authToken", "deviceToken", "deviceId"]
        keys.forEach { delete(key: $0) }
    }
    
    /// Check if pairing credentials exist
    static var hasPairing: Bool {
        return load(key: "gatewayURL") != nil && load(key: "authToken") != nil
    }
}
