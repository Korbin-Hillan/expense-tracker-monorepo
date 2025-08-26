//
//  TransactionsAPI.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import Foundation

struct TransactionDTO: Codable, Identifiable {
    let id: String
    let type: String          // "expense" | "income"
    let amount: Double
    let category: String
    let note: String?
    let date: String          // ISO 8601
}

struct CreateTransactionBody: Codable {
    let type: String
    let amount: Double
    let category: String
    let note: String?
    let date: String          // ISO 8601
}

enum TxError: LocalizedError { case badResponse, server(String) }

final class TransactionsAPI {
    private let base = URL(string: "http://192.168.0.119:3000")!

    func create(_ body: CreateTransactionBody) async throws -> TransactionDTO {
        print("🔥 TransactionsAPI: Creating transaction with body: \(body)")
        
        let url = base.appendingPathComponent("/api/transactions")
        print("🌐 TransactionsAPI: Request URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            req.httpBody = try JSONEncoder().encode(body)
            print("📤 TransactionsAPI: Request body encoded successfully")
        } catch {
            print("❌ TransactionsAPI: Failed to encode request body: \(error)")
            throw TxError.badResponse
        }
        
        do {
            print("🔐 TransactionsAPI: Making authenticated request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else { 
                print("❌ TransactionsAPI: No HTTP response received")
                throw TxError.badResponse 
            }
            
            print("📥 TransactionsAPI: Response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: Response body: \(responseBody)")
            
            
            if (200...299).contains(http.statusCode) {
                do {
                    let transaction = try JSONDecoder().decode(TransactionDTO.self, from: data)
                    print("✅ TransactionsAPI: Transaction created successfully: \(transaction.id)")
                    return transaction
                } catch {
                    print("❌ TransactionsAPI: Failed to decode response: \(error)")
                    throw TxError.server("Failed to decode server response")
                }
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: Server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
        } catch {
            print("❌ TransactionsAPI: Request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }

    func list(limit: Int = 20, skip: Int = 0) async throws -> [TransactionDTO] {
        print("📋 TransactionsAPI: Listing transactions (limit: \(limit), skip: \(skip))")
        
        var comps = URLComponents(url: base.appendingPathComponent("/api/transactions"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "limit", value: String(limit)),
            .init(name: "skip", value: String(skip))
        ]
        
        guard let url = comps.url else {
            print("❌ TransactionsAPI: Failed to construct URL")
            throw TxError.badResponse
        }
        
        print("🌐 TransactionsAPI: Request URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            print("🔐 TransactionsAPI: Making authenticated list request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                print("❌ TransactionsAPI: No HTTP response received for list")
                throw TxError.badResponse
            }
            
            print("📥 TransactionsAPI: List response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: List response body: \(responseBody)")
            
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: List server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            do {
                let transactions = try JSONDecoder().decode([TransactionDTO].self, from: data)
                print("✅ TransactionsAPI: Successfully loaded \(transactions.count) transactions")
                return transactions
            } catch {
                print("❌ TransactionsAPI: Failed to decode transactions list: \(error)")
                throw TxError.server("Failed to decode transactions")
            }
        } catch {
            print("❌ TransactionsAPI: List request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    func update(_ id: String, _ body: CreateTransactionBody) async throws -> TransactionDTO {
        print("📝 TransactionsAPI: Updating transaction \(id) with body: \(body)")
        
        let url = base.appendingPathComponent("/api/transactions/\(id)")
        print("🌐 TransactionsAPI: Update URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            req.httpBody = try JSONEncoder().encode(body)
            print("📤 TransactionsAPI: Update request body encoded successfully")
        } catch {
            print("❌ TransactionsAPI: Failed to encode update request body: \(error)")
            throw TxError.badResponse
        }
        
        do {
            print("🔐 TransactionsAPI: Making authenticated update request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                print("❌ TransactionsAPI: No HTTP response received for update")
                throw TxError.badResponse
            }
            
            print("📥 TransactionsAPI: Update response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: Update response body: \(responseBody)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: Update server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            do {
                let transaction = try JSONDecoder().decode(TransactionDTO.self, from: data)
                print("✅ TransactionsAPI: Transaction updated successfully: \(transaction.id)")
                return transaction
            } catch {
                print("❌ TransactionsAPI: Failed to decode update response: \(error)")
                throw TxError.server("Failed to decode server response")
            }
        } catch {
            print("❌ TransactionsAPI: Update request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    func delete(_ id: String) async throws {
        print("🗑️ TransactionsAPI: Deleting transaction \(id)")
        
        let url = base.appendingPathComponent("/api/transactions/\(id)")
        print("🌐 TransactionsAPI: Delete URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            print("🔐 TransactionsAPI: Making authenticated delete request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                print("❌ TransactionsAPI: No HTTP response received for delete")
                throw TxError.badResponse
            }
            
            print("📥 TransactionsAPI: Delete response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: Delete response body: \(responseBody)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: Delete server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            print("✅ TransactionsAPI: Transaction deleted successfully: \(id)")
        } catch {
            print("❌ TransactionsAPI: Delete request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
}
