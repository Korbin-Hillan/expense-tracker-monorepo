//
//  UserAPI.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/28/25.
//

import Foundation

struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String
    let deletedData: DeletedDataSummary
}

struct DeletedDataSummary: Codable {
    let refreshTokens: Int
    let transactions: Int
    let expenses: Int
}

enum UserAPIError: LocalizedError {
    case badResponse
    case server(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "Invalid server response"
        case .server(let message):
            return message
        case .notAuthenticated:
            return "Authentication required"
        }
    }
}

final class UserAPI {
    private let base = AppConfig.baseURL
    
    func deleteAccount() async throws -> DeleteAccountResponse {
        Logger.shared.debug("Attempting to delete user account")
        
        let url = base.appendingPathComponent("/api/account")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                Logger.shared.error("No HTTP response received for delete account")
                throw UserAPIError.badResponse
            }
            
            Logger.shared.verbose("Delete account response status: \(http.statusCode)")
            
            switch http.statusCode {
            case 200:
                let response = try JSONDecoder().decode(DeleteAccountResponse.self, from: data)
                Logger.shared.info("Account deleted successfully")
                return response
                
            case 401:
                Logger.shared.error("Unauthorized - invalid or expired token")
                throw UserAPIError.notAuthenticated
                
            case 404:
                Logger.shared.error("User not found")
                throw UserAPIError.server("Account not found")
                
            default:
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.shared.error("Delete account server error \(http.statusCode): \(msg)")
                throw UserAPIError.server("Server error: \(msg)")
            }
            
        } catch {
            if error is UserAPIError {
                throw error
            } else {
                Logger.shared.error("Delete account request failed: \(error.localizedDescription)")
                throw UserAPIError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
}