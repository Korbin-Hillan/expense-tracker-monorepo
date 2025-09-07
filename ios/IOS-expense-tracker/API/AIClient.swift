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

// MARK: - GPT integrations
struct SavingsPlaybook: Codable { struct Item: Codable { let title: String; let description: String; let impact: String? }; let items: [Item] }
struct BudgetItem: Codable { let category: String; let suggestedMonthly: Double }
struct SubscriptionItem: Codable { let note: String; let monthlyEstimate: Double; let priority: String? }
struct GPTInsightsPayload: Codable {
    let insights: [AIInsight]
    let narrative: String?
    let savings_playbook: SavingsPlaybook?
    let budget: [BudgetItem]?
    let subscriptions: [SubscriptionItem]?
}

extension AIClient {
    struct ServerSubsResponse: Codable { let subs: [ServerSub] }
    struct ServerSub: Codable, Identifiable { var id: String { note }; let note: String; let count: Int; let avg: Double; let monthlyEstimate: Double; let frequency: String }

    func serverSubscriptions() async throws -> [ServerSub] {
        let url = base.appendingPathComponent("/api/ai/subscriptions")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(ServerSubsResponse.self, from: data).subs
    }
    func gptInsights() async throws -> GPTInsightsPayload {
        let url = base.appendingPathComponent("/api/ai/insights/gpt")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(GPTInsightsPayload.self, from: data)
    }

    func askGPT(_ prompt: String) async throws -> String {
        let url = base.appendingPathComponent("/api/ai/assistant/gpt")
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

    func weeklyDigest() async throws -> String {
        let url = base.appendingPathComponent("/api/ai/digest/gpt")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        struct Digest: Codable { let digest: String }
        return try JSONDecoder().decode(Digest.self, from: data).digest
    }

    // Streaming chat via SSE
    func askGPTStream(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build request
                    let url = base.appendingPathComponent("/api/ai/assistant/gpt/stream")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let body = try JSONSerialization.data(withJSONObject: ["prompt": prompt], options: [])
                    req.httpBody = body

                    // Attach auth header
                    let token = try await AuthSession.shared.validAccessToken()
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                    // Stream bytes
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw TxError.server("stream_bad_response")
                    }

                    var buffer = Data()
                    for try await chunk in bytes {
                        buffer.append(chunk)
                        // Split on double newlines (SSE event boundary)
                        while let range = buffer.range(of: Data("\n\n".utf8)) {
                            let eventData = buffer.subdata(in: 0..<range.lowerBound)
                            buffer.removeSubrange(0..<range.upperBound)
                            if let line = String(data: eventData, encoding: .utf8) {
                                // Parse OpenAI SSE line(s)
                                for raw in line.components(separatedBy: "\n") {
                                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard trimmed.hasPrefix("data:") else { continue }
                                    let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                    if payload == "[DONE]" { continuation.finish(); return }
                                    if let json = payload.data(using: .utf8) {
                                        if let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                                           let choices = obj["choices"] as? [[String: Any]],
                                           let delta = choices.first?["delta"] as? [String: Any],
                                           let content = delta["content"] as? String, !content.isEmpty {
                                            continuation.yield(content)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Health score and alerts
extension AIClient {
    struct HealthComponent: Codable { let key: String; let label: String; let score: Int; let max: Int }
    struct HealthScoreResponse: Codable { let score: Int; let components: [HealthComponent]; let recommendations: [String] }
    struct AlertItem: Codable, Identifiable { let id: String; let title: String; let body: String; let severity: String; let key: String? }
    private struct AlertsResponse: Codable { let alerts: [AlertItem] }

    func healthScore() async throws -> HealthScoreResponse {
        let url = base.appendingPathComponent("/api/ai/health-score")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(HealthScoreResponse.self, from: data)
    }

    func alerts() async throws -> [AlertItem] {
        let url = base.appendingPathComponent("/api/ai/alerts")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return try JSONDecoder().decode(AlertsResponse.self, from: data).alerts
    }
}

// MARK: - Preferences (alerts/subscriptions)
extension AIClient {
    func setAlertPref(key: String, mute: Bool) async throws {
        let url = base.appendingPathComponent("/api/ai/alerts/prefs")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["key": key, "mute": mute])
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
    }

    func setSubscriptionPref(note: String, ignore: Bool?, cancel: Bool?) async throws {
        let url = base.appendingPathComponent("/api/ai/subscriptions/prefs")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["note": note]
        if let ignore = ignore { payload["ignore"] = ignore }
        if let cancel = cancel { payload["cancel"] = cancel }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
    }

    func exportSubscriptionsCSV() async throws -> Data {
        let url = base.appendingPathComponent("/api/ai/subscriptions/export.csv")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, resp) = try await AuthSession.shared.authedRequest(req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "server_error"
            throw TxError.server(msg)
        }
        return data
    }
}
