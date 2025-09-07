//
//  BudgetsAPI.swift
//  IOS-expense-tracker
//

import Foundation

struct BudgetItemDTO: Codable, Identifiable {
    let id: String
    let category: String
    let monthly: Double
}

struct BudgetStatusItem: Codable, Identifiable {
    var id: String { category }
    let category: String
    let monthly: Double
    let spent: Double
    let remaining: Double
    let level: String // ok|warn|danger
}

struct BudgetStatusResponse: Codable {
    let month: String
    let status: [BudgetStatusItem]
}

final class BudgetsAPI {
    private let base = AppConfig.baseURL

    func list() async throws -> [BudgetItemDTO] {
        var req = URLRequest(url: base.appendingPathComponent("/api/budgets"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode([BudgetItemDTO].self, from: data)
    }

    func set(_ budgets: [BudgetItemDTO]) async throws -> [BudgetItemDTO] {
        var req = URLRequest(url: base.appendingPathComponent("/api/budgets"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload = ["budgets": budgets.map { ["category": $0.category, "monthly": $0.monthly] }]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        struct Resp: Codable { let budgets: [BudgetItemDTO] }
        return try JSONDecoder().decode(Resp.self, from: data).budgets
    }

    func status() async throws -> BudgetStatusResponse {
        var req = URLRequest(url: base.appendingPathComponent("/api/budgets/status"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(BudgetStatusResponse.self, from: data)
    }
}

