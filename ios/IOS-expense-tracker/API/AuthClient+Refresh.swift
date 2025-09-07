// AuthClient+Refresh.swift
import Foundation

struct RefreshResponse: Codable {
    let token: String
    let refresh_token: String?
}

extension AuthClient {
    func refresh(with refreshToken: String) async throws -> RefreshResponse {
        #if DEBUG
        print("🔄 AuthClient: Starting token refresh...")
        print("🔄 AuthClient: Refresh token: \(refreshToken.prefix(20))...")
        #endif
        
        let url = base.appendingPathComponent("/api/auth/refresh")
        #if DEBUG
        print("🌐 AuthClient: Refresh URL: \(url)")
        #endif
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let requestBody = ["refresh_token": refreshToken]
        req.httpBody = try JSONEncoder().encode(requestBody)
        
        #if DEBUG
        print("📤 AuthClient: Sending refresh request...")
        #endif
        let (data, resp) = try await AuthSession.shared.rawRequest(req, retries: 1)
        guard let http = resp as? HTTPURLResponse else {
            #if DEBUG
            print("❌ AuthClient: No HTTP response for refresh")
            #endif
            throw AuthError.badResponse
        }
        
        #if DEBUG
        print("📥 AuthClient: Refresh response status: \(http.statusCode)")
        let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
        print("📥 AuthClient: Refresh response body: \(responseBody)")
        #endif
        
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("❌ AuthClient: Refresh failed with status \(http.statusCode)")
            #endif
            throw AuthError.server("refresh_failed")
        }
        
        let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
        #if DEBUG
        print("✅ AuthClient: Token refresh successful")
        print("🔐 AuthClient: New token: \(refreshResponse.token.prefix(50))...")
        #endif
        
        return refreshResponse
    }
}
