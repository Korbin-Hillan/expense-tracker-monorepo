//
//  AIClient.swift
//  IOS-expense-tracker
//

import Foundation

struct InsightAction: Codable {
    let type: String
    let notes: [String]?
    let category: String?
    let transactionIds: [String]?
}

struct AIInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let confidence: Double
    let actionable: Bool?
    let action: InsightAction?
}

struct AIInsightsResponse: Codable {
    let insights: [AIInsight]
}

final class AIClient {
    private let base = AppConfig.baseURL

    func generateInsights() async throws -> [AIInsight] {
        let url = base.appendingPathComponent("/api/ai/insights")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(AIInsightsResponse.self, from: data).insights
    }

    func apply(action: InsightAction) async throws -> ApplyResult {
        let url = base.appendingPathComponent("/api/ai/insights/apply")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(["action": action])

        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(ApplyResult.self, from: data)
    }
}

struct ApplyResult: Codable {
    let success: Bool
    let modified: Int?
}

struct AssistantResponse: Codable { let reply: String }

extension AIClient {
    func ask(_ prompt: String) async throws -> String {
        let url = base.appendingPathComponent("/api/ai/assistant")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(["prompt": prompt])

        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(AssistantResponse.self, from: data).reply
    }
}
