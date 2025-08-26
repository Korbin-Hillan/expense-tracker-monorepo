// AuthClient+Refresh.swift
import Foundation

struct RefreshResponse: Codable {
    let token: String
    let refresh_token: String?
}

extension AuthClient {
    func refresh(with refreshToken: String) async throws -> RefreshResponse {
        print("🔄 AuthClient: Starting token refresh...")
        print("🔄 AuthClient: Refresh token: \(refreshToken.prefix(20))...")
        
        let url = URL(string: "http://192.168.0.119:3000/api/auth/refresh")!
        print("🌐 AuthClient: Refresh URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let requestBody = ["refresh_token": refreshToken]
        req.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤 AuthClient: Sending refresh request...")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            print("❌ AuthClient: No HTTP response for refresh")
            throw AuthError.badResponse
        }
        
        print("📥 AuthClient: Refresh response status: \(http.statusCode)")
        let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
        print("📥 AuthClient: Refresh response body: \(responseBody)")
        
        guard (200..<300).contains(http.statusCode) else {
            print("❌ AuthClient: Refresh failed with status \(http.statusCode)")
            throw AuthError.server("refresh_failed: \(responseBody)")
        }
        
        let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
        print("✅ AuthClient: Token refresh successful")
        print("🔐 AuthClient: New token: \(refreshResponse.token.prefix(50))...")
        
        return refreshResponse
    }
}
