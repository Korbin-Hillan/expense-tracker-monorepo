// AuthSession.swift
import Foundation
import SwiftUI

final class AuthSession {
    static let shared = AuthSession()
    private init() {}

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    /// Returns a valid access token, refreshing if needed.
    func validAccessToken() async throws -> String {
        #if DEBUG
        print("🔍 AuthSession: Checking for valid access token...")
        #endif
        
        guard let token = loadToken() else { 
            #if DEBUG
            print("❌ AuthSession: No token found in keychain")
            #endif
            throw AuthError.notAuthenticated 
        }
        
        #if DEBUG
        print("🔐 AuthSession: Found token in keychain: \(token.prefix(50))...")
        print("🔐 AuthSession: Checking if token is expired...")
        #endif
        
        if !JWTHelpers.isExpired(token) { 
            #if DEBUG
            print("✅ AuthSession: Token is still valid")
            #endif
            return token 
        }
        
        #if DEBUG
        print("⏰ AuthSession: Token is expired, attempting refresh...")
        #endif

        guard let rt = loadRefreshToken() else { 
            #if DEBUG
            print("❌ AuthSession: No refresh token found")
            #endif
            throw AuthError.notAuthenticated 
        }
        
        #if DEBUG
        print("🔄 AuthSession: Using refresh token: \(rt.prefix(20))...")
        #endif
        
        let refreshed = try await AuthClient().refresh(with: rt)
        #if DEBUG
        print("✅ AuthSession: Got refreshed token: \(refreshed.token.prefix(50))...")
        #endif
        
        saveToken(refreshed.token)
        if let newRT = refreshed.refresh_token { 
            #if DEBUG
            print("🔄 AuthSession: Got new refresh token, saving...")
            #endif
            saveRefreshToken(newRT) 
        }
        return refreshed.token
    }

    // Raw request with optional retries/backoff for unauthenticated endpoints
    @discardableResult
    func rawRequest(_ req: URLRequest, retries: Int = 0) async throws -> (Data, URLResponse) {
        var attempt = 0
        var lastError: Error?
        var req = req
        while attempt <= retries {
            do {
                return try await session.data(for: req)
            } catch {
                lastError = error
                if attempt == retries { break }
                // Exponential backoff: 200ms, 400ms, ...
                let backoffMs = 200 * Int(pow(2.0, Double(attempt)))
                try? await Task.sleep(nanoseconds: UInt64(backoffMs) * 1_000_000)
                // Add idempotency key to safe methods
                if req.httpMethod == "GET" || req.httpMethod == "HEAD" {
                    req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Idempotency-Key")
                }
                attempt += 1
            }
        }
        throw lastError ?? AuthError.networkError
    }

    /// Wrap any API call with this to auto-attach token and refresh once on 401.
    @discardableResult
    func authedRequest(_ req: URLRequest) async throws -> (Data, URLResponse) {
        var req = req
        let token = try await validAccessToken()
        
        #if DEBUG
        print("🔐 AuthSession: Using token: \(token.prefix(50))...")
        print("🔐 AuthSession: Token length: \(token.count) characters")
        #endif
        
        // Check if token looks valid (should be JWT format)
        let parts = token.split(separator: ".")
        #if DEBUG
        print("🔐 AuthSession: Token parts count: \(parts.count) (should be 3 for JWT)")
        #endif
        
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            #if DEBUG
            print("🔄 AuthSession: Got 401, attempting token refresh...")
            #endif
            
            // Try one refresh and retry
            guard let rt = loadRefreshToken() else { 
                #if DEBUG
                print("❌ AuthSession: No refresh token available")
                #endif
                throw AuthError.notAuthenticated 
            }
            
            #if DEBUG
            print("🔄 AuthSession: Found refresh token: \(rt.prefix(20))...")
            #endif
            
            do {
                let refreshed = try await AuthClient().refresh(with: rt)
                #if DEBUG
                print("✅ AuthSession: Token refreshed successfully")
                print("🔐 AuthSession: New token: \(refreshed.token.prefix(50))...")
                #endif
                
                saveToken(refreshed.token)
                if let newRT = refreshed.refresh_token { 
                    #if DEBUG
                    print("🔄 AuthSession: Saving new refresh token")
                    #endif
                    saveRefreshToken(newRT) 
                }

                var retry = req
                retry.setValue("Bearer \(refreshed.token)", forHTTPHeaderField: "Authorization")
                #if DEBUG
                print("🔄 AuthSession: Retrying request with new token")
                #endif
                return try await session.data(for: retry)
            } catch {
                #if DEBUG
                print("❌ AuthSession: Token refresh failed: \(error)")
                #endif
                throw error
            }
        }
        return (data, resp)
    }
}
