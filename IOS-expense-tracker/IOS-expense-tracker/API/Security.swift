// Security.swift
import Security
import SwiftUI

private let TOKEN_SERVICE = "com.korbinhillan.expense-tracker" // ONE canonical value
private let TOKEN_ACCOUNT = "app.jwt"
private let REFRESH_ACCOUNT = "app.refresh"

func saveToken(_ token: String) {
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: TOKEN_ACCOUNT,
        kSecValueData as String: Data(token.utf8),
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    // delete then add
    SecItemDelete([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: TOKEN_ACCOUNT
    ] as CFDictionary)
    let status = SecItemAdd(q as CFDictionary, nil)
    #if DEBUG
    if status != errSecSuccess {
        print("❌ Keychain save error:", status)
    } else {
        print("🔐 saved token (\(token.count) chars)")
    }
    #endif
}

func loadToken() -> String? {
    var item: CFTypeRef?
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: TOKEN_ACCOUNT,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let s = String(data: data, encoding: .utf8) else {
        #if DEBUG
        if status != errSecSuccess {
            print("⚠️ loadToken status:", status)
            if status == errSecItemNotFound {
                print("🔍 No token found in keychain")
            }
        }
        #endif
        return nil
    }
    
    #if DEBUG
    print("🔐 loadToken: Retrieved token from keychain: \(s.prefix(50))...")
    print("🔐 loadToken: Token length: \(s.count) characters")
    let parts = s.split(separator: ".")
    print("🔐 loadToken: Token parts: \(parts.count) (should be 3 for JWT)")
    #endif
    
    return s
}

func saveRefreshToken(_ rt: String) {
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: REFRESH_ACCOUNT,
        kSecValueData as String: Data(rt.utf8),
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                   kSecAttrService as String: TOKEN_SERVICE,
                   kSecAttrAccount as String: REFRESH_ACCOUNT] as CFDictionary)
    SecItemAdd(q as CFDictionary, nil)
}

func loadRefreshToken() -> String? {
    var item: CFTypeRef?
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: REFRESH_ACCOUNT,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

func clearTokens() {
    let tokenQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: TOKEN_ACCOUNT
    ]
    
    let refreshQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: TOKEN_SERVICE,
        kSecAttrAccount as String: REFRESH_ACCOUNT
    ]
    
    let tokenStatus = SecItemDelete(tokenQuery as CFDictionary)
    let refreshStatus = SecItemDelete(refreshQuery as CFDictionary)
    
    #if DEBUG
    if tokenStatus == errSecSuccess || tokenStatus == errSecItemNotFound {
        print("🔓 Cleared access token")
    } else {
        print("❌ Failed to clear access token:", tokenStatus)
    }
    if refreshStatus == errSecSuccess || refreshStatus == errSecItemNotFound {
        print("🔓 Cleared refresh token")
    } else {
        print("❌ Failed to clear refresh token:", refreshStatus)
    }
    #endif
}
