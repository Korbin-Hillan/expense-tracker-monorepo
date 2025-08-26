// AuthSession.swift
import Foundation
import SwiftUI

final class AuthSession {
    static let shared = AuthSession()
    private init() {}

    /// Returns a valid access token, refreshing if needed.
    func validAccessToken() async throws -> String {
        print("🔍 AuthSession: Checking for valid access token...")
        
        guard let token = loadToken() else { 
            print("❌ AuthSession: No token found in keychain")
            throw AuthError.notAuthenticated 
        }
        
        print("🔐 AuthSession: Found token in keychain: \(token.prefix(50))...")
        print("🔐 AuthSession: Checking if token is expired...")
        
        if !JWTHelpers.isExpired(token) { 
            print("✅ AuthSession: Token is still valid")
            return token 
        }
        
        print("⏰ AuthSession: Token is expired, attempting refresh...")

        guard let rt = loadRefreshToken() else { 
            print("❌ AuthSession: No refresh token found")
            throw AuthError.notAuthenticated 
        }
        
        print("🔄 AuthSession: Using refresh token: \(rt.prefix(20))...")
        
        let refreshed = try await AuthClient().refresh(with: rt)
        print("✅ AuthSession: Got refreshed token: \(refreshed.token.prefix(50))...")
        
        saveToken(refreshed.token)
        if let newRT = refreshed.refresh_token { 
            print("🔄 AuthSession: Got new refresh token, saving...")
            saveRefreshToken(newRT) 
        }
        return refreshed.token
    }

    /// Wrap any API call with this to auto-attach token and refresh once on 401.
    @discardableResult
    func authedRequest(_ req: URLRequest) async throws -> (Data, URLResponse) {
        var req = req
        let token = try await validAccessToken()
        
        print("🔐 AuthSession: Using token: \(token.prefix(50))...")
        print("🔐 AuthSession: Token length: \(token.count) characters")
        
        // Check if token looks valid (should be JWT format)
        let parts = token.split(separator: ".")
        print("🔐 AuthSession: Token parts count: \(parts.count) (should be 3 for JWT)")
        
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            print("🔄 AuthSession: Got 401, attempting token refresh...")
            
            // Try one refresh and retry
            guard let rt = loadRefreshToken() else { 
                print("❌ AuthSession: No refresh token available")
                throw AuthError.notAuthenticated 
            }
            
            print("🔄 AuthSession: Found refresh token: \(rt.prefix(20))...")
            
            do {
                let refreshed = try await AuthClient().refresh(with: rt)
                print("✅ AuthSession: Token refreshed successfully")
                print("🔐 AuthSession: New token: \(refreshed.token.prefix(50))...")
                
                saveToken(refreshed.token)
                if let newRT = refreshed.refresh_token { 
                    print("🔄 AuthSession: Saving new refresh token")
                    saveRefreshToken(newRT) 
                }

                var retry = req
                retry.setValue("Bearer \(refreshed.token)", forHTTPHeaderField: "Authorization")
                print("🔄 AuthSession: Retrying request with new token")
                return try await URLSession.shared.data(for: retry)
            } catch {
                print("❌ AuthSession: Token refresh failed: \(error)")
                throw error
            }
        }
        return (data, resp)
    }
}
