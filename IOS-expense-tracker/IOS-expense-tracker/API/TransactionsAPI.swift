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

struct TransactionSummary: Codable {
    let totalTransactions: Int
    let totalIncome: Double
    let totalExpenses: Double
    let netAmount: Double
    let categorySummary: [String: CategorySummary]
    let dateRange: DateRange
    
    struct CategorySummary: Codable {
        let count: Int
        let total: Double
    }
    
    struct DateRange: Codable {
        let from: String
        let to: String
    }
}

struct ImportableTransaction: Codable {
    let date: String
    let description: String
    let amount: Double
    let type: String?
    let category: String?
    let note: String?
}

struct ImportError: Codable {
    let row: Int
    let field: String
    let message: String
}

struct ImportResult: Codable {
    let totalRows: Int
    let validTransactions: Int
    let errors: [ImportError]
    let preview: [ImportableTransaction]
    let duplicates: [ImportableTransaction]
}

struct ImportCommitResult: Codable {
    let success: Bool
    let totalProcessed: Int
    let inserted: Int
    let duplicatesSkipped: Int
    let errors: [ImportError]
}

struct ColumnMapping: Codable {
    let dateColumn: String
    let descriptionColumn: String
    let amountColumn: String
    let typeColumn: String?
    let categoryColumn: String?
    let noteColumn: String?
}

struct FileColumnsResult: Codable {
    let columns: [String]
    let sheets: [String]
    let suggestedMapping: SuggestedMapping
    
    struct SuggestedMapping: Codable {
        let date: String?
        let description: String?
        let amount: String?
        let type: String?
        let category: String?
        let note: String?
    }
}

enum TxError: LocalizedError {
    case badResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "Unexpected response from server. Please try again."
        case .server(let message):
            // Provide a safer, user-friendly description while preserving server detail
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Server returned an error." }
            return trimmed
        }
    }
}

final class TransactionsAPI {
    private let base = AppConfig.baseURL

    func create(_ body: CreateTransactionBody) async throws -> TransactionDTO {
        Logger.shared.debug("Creating transaction with category: \(body.category)")
        
        let url = base.appendingPathComponent("/api/transactions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            req.httpBody = try JSONEncoder().encode(body)
        } catch {
            Logger.shared.error("Failed to encode request body: \(error)")
            throw TxError.badResponse
        }
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else { 
                Logger.shared.error("No HTTP response received")
                throw TxError.badResponse 
            }
            
            Logger.shared.verbose("Response status: \(http.statusCode)")
            
            if (200...299).contains(http.statusCode) {
                do {
                    let transaction = try JSONDecoder().decode(TransactionDTO.self, from: data)
                    Logger.shared.info("Transaction created successfully: \(transaction.id)")
                    return transaction
                } catch {
                    Logger.shared.error("Failed to decode response: \(error)")
                    throw TxError.server("Failed to decode server response")
                }
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                Logger.shared.error("Server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
        } catch {
            if error is TxError {
                throw error
            } else {
                Logger.shared.error("Network request failed: \(error.localizedDescription)")
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }

    func list(limit: Int = AppConfig.API.defaultPageSize, skip: Int = 0) async throws -> [TransactionDTO] {
        Logger.shared.debug("Listing transactions (limit: \(limit), skip: \(skip))")
        
        var comps = URLComponents(url: base.appendingPathComponent("/api/transactions"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "limit", value: String(limit)),
            .init(name: "skip", value: String(skip))
        ]
        
        guard let url = comps.url else {
            Logger.shared.error("Failed to construct URL")
            throw TxError.badResponse
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                Logger.shared.error("No HTTP response received for list")
                throw TxError.badResponse
            }
            
            Logger.shared.verbose("List response status: \(http.statusCode)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                Logger.shared.error("List server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            do {
                let transactions = try JSONDecoder().decode([TransactionDTO].self, from: data)
                Logger.shared.info("Successfully loaded \(transactions.count) transactions")
                return transactions
            } catch {
                Logger.shared.error("Failed to decode transactions list: \(error)")
                throw TxError.server("Failed to decode transactions")
            }
        } catch {
            if error is TxError {
                throw error
            } else {
                Logger.shared.error("Network request failed: \(error.localizedDescription)")
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
        Logger.shared.debug("Deleting transaction \(id)")
        
        let url = base.appendingPathComponent("/api/transactions/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                Logger.shared.error("No HTTP response received for delete")
                throw TxError.badResponse
            }
            
            Logger.shared.verbose("Delete response status: \(http.statusCode)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                Logger.shared.error("Delete server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            Logger.shared.info("Transaction deleted successfully: \(id)")
        } catch {
            if error is TxError {
                throw error
            } else {
                Logger.shared.error("Delete request failed: \(error.localizedDescription)")
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAll() async throws {
        print("🧹 TransactionsAPI: Clearing all transactions")
        
        let url = base.appendingPathComponent("/api/transactions/clear")
        print("🌐 TransactionsAPI: Clear all URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            print("🔐 TransactionsAPI: Making authenticated clear all request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                print("❌ TransactionsAPI: No HTTP response received for clear all")
                throw TxError.badResponse
            }
            
            print("📥 TransactionsAPI: Clear all response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: Clear all response body: \(responseBody)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: Clear all server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            print("✅ TransactionsAPI: All transactions cleared successfully")
        } catch {
            print("❌ TransactionsAPI: Clear all request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Export Methods
    
    func getSummary(startDate: String? = nil, endDate: String? = nil, category: String? = nil, type: String? = nil) async throws -> TransactionSummary {
        print("📊 TransactionsAPI: Getting transaction summary")
        
        var comps = URLComponents(url: base.appendingPathComponent("/api/transactions/summary"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let startDate = startDate { queryItems.append(.init(name: "startDate", value: startDate)) }
        if let endDate = endDate { queryItems.append(.init(name: "endDate", value: endDate)) }
        if let category = category, category != "all" { queryItems.append(.init(name: "category", value: category)) }
        if let type = type, type != "all" { queryItems.append(.init(name: "type", value: type)) }
        
        if !queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        
        guard let url = comps.url else {
            print("❌ TransactionsAPI: Failed to construct summary URL")
            throw TxError.badResponse
        }
        
        print("🌐 TransactionsAPI: Summary URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                throw TxError.badResponse
            }
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                throw TxError.server(msg)
            }
            
            let summary = try JSONDecoder().decode(TransactionSummary.self, from: data)
            print("✅ TransactionsAPI: Successfully loaded summary")
            return summary
        } catch {
            print("❌ TransactionsAPI: Summary request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    func exportCSV(startDate: String? = nil, endDate: String? = nil, category: String? = nil, type: String? = nil) async throws -> Data {
        return try await exportFile(format: "csv", startDate: startDate, endDate: endDate, category: category, type: type)
    }
    
    func exportExcel(startDate: String? = nil, endDate: String? = nil, category: String? = nil, type: String? = nil) async throws -> Data {
        return try await exportFile(format: "excel", startDate: startDate, endDate: endDate, category: category, type: type)
    }
    
    private func exportFile(format: String, startDate: String? = nil, endDate: String? = nil, category: String? = nil, type: String? = nil) async throws -> Data {
        print("📁 TransactionsAPI: Exporting \(format) file")
        
        var comps = URLComponents(url: base.appendingPathComponent("/api/transactions/export/\(format)"), resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        if let startDate = startDate { queryItems.append(.init(name: "startDate", value: startDate)) }
        if let endDate = endDate { queryItems.append(.init(name: "endDate", value: endDate)) }
        if let category = category, category != "all" { queryItems.append(.init(name: "category", value: category)) }
        if let type = type, type != "all" { queryItems.append(.init(name: "type", value: type)) }
        
        if !queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        
        guard let url = comps.url else {
            print("❌ TransactionsAPI: Failed to construct export URL")
            throw TxError.badResponse
        }
        
        print("🌐 TransactionsAPI: Export URL: \(url)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(req)
            
            guard let http = resp as? HTTPURLResponse else {
                throw TxError.badResponse
            }
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                throw TxError.server(msg)
            }
            
            print("✅ TransactionsAPI: Successfully exported \(format) file (\(data.count) bytes)")
            return data
        } catch {
            print("❌ TransactionsAPI: Export request failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Network request failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Import Methods
    
    func getFileColumns(fileData: Data, fileName: String) async throws -> FileColumnsResult {
        print("📋 TransactionsAPI: Getting columns for file: \(fileName)")
        print("📋 TransactionsAPI: File data size: \(fileData.count) bytes")
        print("📋 TransactionsAPI: Base URL: \(base.absoluteString)")
        
        let url = base.appendingPathComponent("/api/import/columns")
        print("🌐 TransactionsAPI: Full request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        print("📤 TransactionsAPI: Request body size: \(body.count) bytes")
        
        do {
            print("🔐 TransactionsAPI: Making authenticated columns request...")
            let (data, resp) = try await AuthSession.shared.authedRequest(request)
            
            guard let http = resp as? HTTPURLResponse else {
                print("❌ TransactionsAPI: No HTTP response for columns request")
                throw TxError.badResponse
            }
            
            print("📥 TransactionsAPI: Columns response status: \(http.statusCode)")
            let responseBody = String(data: data, encoding: .utf8) ?? "<no data>"
            print("📥 TransactionsAPI: Columns response body: \(responseBody)")
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                print("❌ TransactionsAPI: Columns server error \(http.statusCode): \(msg)")
                throw TxError.server(msg)
            }
            
            let result = try JSONDecoder().decode(FileColumnsResult.self, from: data)
            print("✅ TransactionsAPI: Successfully detected columns")
            return result
        } catch {
            print("❌ TransactionsAPI: Column detection failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Column detection failed: \(error.localizedDescription)")
            }
        }
    }
    
    func previewImport(fileData: Data, fileName: String, mapping: ColumnMapping, sheetName: String? = nil) async throws -> ImportResult {
        print("👀 TransactionsAPI: Previewing import for file: \(fileName)")
        
        let url = base.appendingPathComponent("/api/import/preview")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add mapping fields
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dateColumn\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mapping.dateColumn)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"descriptionColumn\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mapping.descriptionColumn)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"amountColumn\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mapping.amountColumn)\r\n".data(using: .utf8)!)
        
        if let typeColumn = mapping.typeColumn {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"typeColumn\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(typeColumn)\r\n".data(using: .utf8)!)
        }
        
        if let categoryColumn = mapping.categoryColumn {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"categoryColumn\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(categoryColumn)\r\n".data(using: .utf8)!)
        }
        
        if let noteColumn = mapping.noteColumn {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"noteColumn\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(noteColumn)\r\n".data(using: .utf8)!)
        }
        
        if let sheetName = sheetName {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"sheetName\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(sheetName)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(request)
            
            guard let http = resp as? HTTPURLResponse else {
                throw TxError.badResponse
            }
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                throw TxError.server(msg)
            }
            
            let result = try JSONDecoder().decode(ImportResult.self, from: data)
            print("✅ TransactionsAPI: Successfully previewed import - \(result.validTransactions) valid transactions")
            return result
        } catch {
            print("❌ TransactionsAPI: Import preview failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Import preview failed: \(error.localizedDescription)")
            }
        }
    }
    
    func commitImport(fileData: Data, fileName: String, mapping: ColumnMapping, skipDuplicates: Bool = true, sheetName: String? = nil) async throws -> ImportCommitResult {
        print("💾 TransactionsAPI: Committing import for file: \(fileName)")
        
        let url = base.appendingPathComponent("/api/import/commit")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add mapping and settings
        let formFields: [String: String] = [
            "dateColumn": mapping.dateColumn,
            "descriptionColumn": mapping.descriptionColumn,
            "amountColumn": mapping.amountColumn,
            "typeColumn": mapping.typeColumn ?? "",
            "categoryColumn": mapping.categoryColumn ?? "",
            "noteColumn": mapping.noteColumn ?? "",
            "skipDuplicates": skipDuplicates ? "true" : "false",
            "sheetName": sheetName ?? ""
        ]
        
        for (key, value) in formFields where !value.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, resp) = try await AuthSession.shared.authedRequest(request)
            
            guard let http = resp as? HTTPURLResponse else {
                throw TxError.badResponse
            }
            
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown_error"
                throw TxError.server(msg)
            }
            
            let result = try JSONDecoder().decode(ImportCommitResult.self, from: data)
            print("✅ TransactionsAPI: Successfully imported \(result.inserted) transactions")
            return result
        } catch {
            print("❌ TransactionsAPI: Import commit failed: \(error)")
            if error is TxError {
                throw error
            } else {
                throw TxError.server("Import commit failed: \(error.localizedDescription)")
            }
        }
    }
}
