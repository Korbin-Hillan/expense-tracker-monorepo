//
//  Auth.swift
//  expense-tracker-backend
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI
import Foundation

private func base64URLDecode(_ s: String) -> Data? {
    var s = s.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s.append("=") } // pad
    return Data(base64Encoded: s)
}

func jwtPayload(_ jwt: String) -> [String: Any]? {
    let parts = jwt.split(separator: ".")
    guard parts.count >= 2,
          let data = base64URLDecode(String(parts[1])),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return obj
}

// Extract exp (seconds since epoch)
func jwtExp(_ jwt: String) -> TimeInterval? {
    guard let payload = jwtPayload(jwt),
          let exp = payload["exp"] as? Double ?? (payload["exp"] as? Int).map(Double.init)
    else { return nil }
    return exp
}

// Is token expired? (with a small early-refresh skew)
func jwtIsExpired(_ jwt: String, skew seconds: TimeInterval = 60) -> Bool {
    guard let exp = jwtExp(jwt) else { return true } // no exp? treat as expired
    let now = Date().timeIntervalSince1970
    return now >= (exp - seconds)
}

// How many seconds left (negative if expired)
func jwtSecondsRemaining(_ jwt: String) -> TimeInterval? {
    guard let exp = jwtExp(jwt) else { return nil }
    return exp - Date().timeIntervalSince1970
}

struct LoginResponse: Codable {
    let token: String
    struct User: Codable { let id: String; let email: String? }
    let user: User
}

struct MeResponse: Codable {
    struct User: Codable {
        let id: String
        let email: String?
        let name: String?
        let provider: String?
        let roles: [String]?
    }
    let user: User
}

func auth(_ idToken: String) async throws -> LoginResponse {
    var req = URLRequest(url: URL(string: "http://172.16.225.231:3000/api/auth/session")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

    // Debug visibility
    print("HTTP", http.statusCode, "bytes:", data.count)
    if let bodyStr = String(data: data, encoding: .utf8) {
        print("Body:", bodyStr.isEmpty ? "<empty>" : bodyStr)
    }

    guard (200...299).contains(http.statusCode) else {
        // Surface server error message if present
        struct ErrMsg: Codable { let error: String? }
        if let msg = try? JSONDecoder().decode(ErrMsg.self, from: data).error {
            throw NSError(domain: "Auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        throw URLError(.badServerResponse)
    }
    
    let login = try JSONDecoder().decode(LoginResponse.self, from: data)
    saveToken(login.token)
    return login
}

func userCheck() async {
    guard let token = loadToken() else {
        print("⚠️ No token stored")
        return
    }
    
    if jwtIsExpired(token, skew: 60) {
        print("🔒 Token expired (or near expiry). Prompt re-login or refresh.")
        // TODO: trigger your login flow (Apple/Google/password)
        return
    } else if let secs = jwtSecondsRemaining(token) {
        print(String(format: "⏳ Token time left: %.0fs", secs))
    }
    
    var req = URLRequest(url: URL(string: "http://172.16.225.231:3000/api/me")!)
    req.httpMethod = "GET"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            print("⚠️ No HTTP response")
            return
        }
        
        if http.statusCode == 200 {
            let me = try JSONDecoder().decode(MeResponse.self, from: data)
            print("✅ Current user:", me.user)
        } else if http.statusCode == 401 {
            print("❌ Token invalid or expired")
        } else {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
            print("❌ Server error", http.statusCode, body)
        }
    } catch {
        print("❌ Request failed:", error.localizedDescription)
    }
}
