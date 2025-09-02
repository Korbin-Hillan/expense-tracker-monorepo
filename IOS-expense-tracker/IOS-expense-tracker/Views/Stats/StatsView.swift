//
//  StatsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var billStorage = BillStorage.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var transactions: [TransactionDTO] = []
    @State private var isLoadingTransactions = false
    @State private var error: Error?
    @State private var showingAgentChat = false
    @State private var recurringCandidates: [RecurringCandidate] = []
    // GPT data
    @State private var gptLoading = false
    @State private var gptError: String? = nil
    @State private var gptInsights: [AIInsight] = []
    @State private var gptNarrative: String? = nil
    @State private var gptSavings: SavingsPlaybook? = nil
    @State private var gptBudget: [BudgetItem] = []
    @State private var gptSubscriptions: [SubscriptionItem] = []
    @State private var gptDigest: String? = nil
    @State private var gptDigestLoading = false
    // Health & alerts
    @State private var healthLoading = false
    @State private var healthScore: AIClient.HealthScoreResponse? = nil
    @State private var alerts: [AIClient.AlertItem] = []
    
    // Use system adaptive colors within material cards
    private var adaptiveTextColor: Color { .primary }
    private var adaptiveSecondaryTextColor: Color { .secondary }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Financial Insights")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("AI-powered analysis of your spending patterns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Quick Stats Card
                if !transactions.isEmpty {
                    quickStatsCard
                }
                
    // Removed local insights button; using ChatGPT only

                // ChatGPT Insights Button
                Button(action: fetchGPT) {
                    HStack {
                        if gptLoading {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                        }
                        Text(gptLoading ? "Getting ChatGPT Insights..." : "Generate ChatGPT Insights")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(gptLoading ? .gray : Palette.accent(for: colorScheme))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Palette.accent(for: colorScheme).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(gptLoading || transactions.isEmpty)

                // Weekly Digest
                Button(action: fetchDigest) {
                    HStack {
                        if gptDigestLoading {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "calendar")
                                .font(.system(size: 18))
                        }
                        Text(gptDigestLoading ? "Generating Weekly Digest..." : "Get Weekly Digest")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(gptDigestLoading ? .gray : Palette.accentSecondary(for: colorScheme))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Palette.accentSecondary(for: colorScheme).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(gptDigestLoading || transactions.isEmpty)

                // Ask AI button (opens conversational agent)
                Button(action: { showingAgentChat = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                        Text("Ask AI About Expenses")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Palette.accent(for: colorScheme))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Palette.accent(for: colorScheme).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(transactions.isEmpty)
                
                // If no data, show empty state
                if transactions.isEmpty && !isLoadingTransactions {
                    noDataView
                }

                // GPT Narrative
                if let narrative = gptNarrative, !narrative.isEmpty {
                    narrativeSection(narrative)
                }

                if let digest = gptDigest, !digest.isEmpty {
                    narrativeSection(digest)
                }

                // Health Score
                if let hs = healthScore {
                    healthSection(hs)
                }

                // Proactive Alerts
                if !alerts.isEmpty {
                    alertsSection(alerts)
                }

                // GPT Insights List
                if !gptInsights.isEmpty {
                    gptInsightsSection
                }

                // Savings Playbook
                if let sp = gptSavings, !sp.items.isEmpty {
                    savingsPlaybookSection(sp)
                }

                // Budget Suggestions
                if !gptBudget.isEmpty {
                    budgetSection(gptBudget)
                }

                // Subscription Detective
                if !gptSubscriptions.isEmpty {
                    subscriptionsSection(gptSubscriptions)
                }

                // (Server Insights removed in favor of conversational agent)

                // Possible Recurring Bills Section
                if !recurringCandidates.isEmpty {
                    recurringCandidatesSection
                }
                
                if let error = error {
                    errorView(error)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .task {
            await loadTransactions()
            await fetchHealthAndAlerts()
        }
        .sheet(isPresented: $showingAgentChat) {
            AgentChatView()
        }
    }
    
    private var quickStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Transactions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(transactions.count)")
                        .font(.title2).fontWeight(.bold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("This Month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(monthlySpending, specifier: "%.2f")")
                        .font(.title2).fontWeight(.bold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(24)
        .cardStyle(cornerRadius: 20)
    }
    
    private var gptInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ChatGPT Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(gptInsights.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(gptInsights, id: \.id) { insight in
                    InsightCard(insight: toSpendingInsight(insight))
                }
            }
        }
    }

    private func narrativeSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Forecast Narrative", systemImage: "text.append")
                .font(.headline)
                .foregroundColor(.primary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }

    private func healthSection(_ hs: AIClient.HealthScoreResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Financial Health", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(hs.score)/100")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hs.score >= 70 ? Color.green : (hs.score >= 40 ? Color.orange : Color.red))
                    .cornerRadius(8)
            }
            ForEach(hs.components, id: \.key) { c in
                HStack {
                    Text(c.label).foregroundColor(.primary)
                    Spacer()
                    Text("\(c.score)/\(c.max)").foregroundColor(.secondary)
                }
                .padding(8)
                .cardStyle(cornerRadius: 8)
            }
            if !hs.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations").font(.subheadline).foregroundColor(.primary)
                    ForEach(hs.recommendations, id: \.self) { r in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb").foregroundColor(.yellow)
                            Text(r).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }

    private func alertsSection(_ items: [AIClient.AlertItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Proactive Alerts", systemImage: "bell.badge")
                .font(.headline)
                .foregroundColor(.primary)
            ForEach(items) { a in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: a.severity == "critical" ? "exclamationmark.triangle.fill" : (a.severity == "warning" ? "exclamationmark.circle" : "info.circle"))
                        .foregroundColor(a.severity == "critical" ? .red : (a.severity == "warning" ? .orange : .blue))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.subheadline).foregroundColor(.primary).fontWeight(.semibold)
                        Text(a.body).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .cardStyle(cornerRadius: 10)
            }
        }
    }

    private func savingsPlaybookSection(_ sp: SavingsPlaybook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Savings Playbook", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            ForEach(Array(sp.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline).foregroundColor(adaptiveTextColor).fontWeight(.semibold)
                    Text(item.description).font(.caption).foregroundColor(adaptiveSecondaryTextColor)
                    if let impact = item.impact { Text(impact).font(.caption2).foregroundColor(.green) }
                }
                .padding(12)
                .background(.white.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    private func budgetSection(_ items: [BudgetItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Budget Coach", systemImage: "target")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            ForEach(items, id: \.category) { b in
                HStack {
                    Text(b.category).foregroundColor(adaptiveTextColor)
                    Spacer()
                    Text("$\(b.suggestedMonthly, specifier: "%.0f")/mo")
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .cornerRadius(6)
                }
                .padding(10)
                .background(.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func subscriptionsSection(_ items: [SubscriptionItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Subscription Detective", systemImage: "magnifyingglass")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(it.note).foregroundColor(adaptiveTextColor).font(.subheadline)
                        if let p = it.priority { Text(p).font(.caption2).foregroundColor(.orange) }
                    }
                    Spacer()
                    Text("~$\(it.monthlyEstimate, specifier: "%.0f")/mo").foregroundColor(.white)
                }
                .padding(10)
                .background(.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // Removed local insights empty state

    // Server Insights UI removed
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No transaction data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Add some transactions to see AI-powered insights about your spending")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .cardStyle(cornerRadius: 16)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Error loading data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await loadTransactions() }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(24)
        .cardStyle(cornerRadius: 16)
    }
    
    private var monthlySpending: Double {
        let calendar = Calendar.current
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        
        return transactions
            .filter { transaction in
                guard let date = dateFormatter.date(from: transaction.date) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func loadTransactions() async {
        isLoadingTransactions = true
        error = nil
        
        do {
            transactions = try await TransactionsAPI().list(limit: 100)
            // Derive recurring candidates on-device
            recurringCandidates = deriveRecurringCandidates(from: transactions)
        } catch {
            self.error = error
            print("❌ StatsView: Failed to load transactions: \(error)")
        }
        
        isLoadingTransactions = false
    }
    
    // Removed local insights refresh; using GPT endpoints

    private func fetchGPT() {
        gptLoading = true
        gptError = nil
        Task {
            defer { gptLoading = false }
            do {
                let payload = try await AIClient().gptInsights()
                await MainActor.run {
                    gptInsights = payload.insights
                    gptNarrative = payload.narrative
                    gptSavings = payload.savings_playbook
                    gptBudget = payload.budget ?? []
                    gptSubscriptions = payload.subscriptions ?? []
                }
            } catch {
                await MainActor.run { gptError = error.localizedDescription }
            }
        }
    }

    private func fetchHealthAndAlerts() async {
        healthLoading = true
        defer { healthLoading = false }
        do {
            async let hs = AIClient().healthScore()
            async let al = AIClient().alerts()
            let (h, a) = try await (hs, al)
            await MainActor.run {
                self.healthScore = h
                self.alerts = a
            }
        } catch {
            print("Failed to load health/alerts: \(error)")
        }
    }

    // Map API AIInsight to local SpendingInsight for UI reuse
    private func toSpendingInsight(_ api: AIInsight) -> SpendingInsight {
        let cat: InsightCategory
        switch api.category.lowercased() {
        case "pattern": cat = .pattern
        case "anomaly": cat = .anomaly
        case "prediction": cat = .prediction
        case "optimization": cat = .optimization
        default: cat = .pattern
        }
        return SpendingInsight(
            title: api.title,
            description: api.description,
            category: cat,
            confidence: api.confidence,
            actionable: api.actionable ?? false
        )
    }

    private func fetchDigest() {
        gptDigestLoading = true
        Task {
            defer { gptDigestLoading = false }
            do {
                let text = try await AIClient().weeklyDigest()
                await MainActor.run { gptDigest = text }
            } catch {
                await MainActor.run { gptDigest = "Failed to generate digest: \(error.localizedDescription)" }
            }
        }
    }

    // fetchServerInsights removed

    // MARK: - Recurring Candidates
    private struct RecurringCandidate: Identifiable {
        let id = UUID()
        let name: String
        let averageAmount: Double
        let frequency: BillFrequency
        let occurrences: Int
        let lastSeen: Date
        let nextDue: Date?
        let category: String
    }

    private func deriveRecurringCandidates(from txs: [TransactionDTO]) -> [RecurringCandidate] {
        let iso = ISO8601DateFormatter()
        // Heuristics to avoid false positives (e.g., Walmart, groceries, gas)
        let excludeCategories: Set<String> = [
            "Groceries", "Grocery", "Supermarket", "Restaurants", "Dining",
            "Gas", "Fuel", "Retail", "Pharmacy", "Coffee"
        ]
        let excludeKeywords: [String] = [
            "walmart", "target", "costco", "kroger", "safeway", "whole foods",
            "aldi", "heb", "publix", "winco", "chevron", "shell", "exxon",
            "mcdonald", "starbucks", "chipotle", "uber", "doordash", "instacart"
        ]
        let subscriptionKeywords: [String] = [
            "subscription", "member", "membership", "plan", "service",
            "tv", "stream", "cloud", "storage", "music", "news",
            "netflix", "hulu", "spotify", "apple", "google", "adobe",
            "microsoft", "prime", "dropbox", "notion", "1password",
            "att", "verizon", "t-mobile", "xfinity", "comcast",
            "internet", "utilities", "water", "electric", "power",
            "insurance", "gym", "fitness"
        ]

        // Group by normalized note
        var groups: [String: [TransactionDTO]] = [:]
        for t in txs where t.type == "expense" {
            let key = (t.note ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { continue }
            groups[key, default: []].append(t)
        }

        func guessFrequency(_ medianGap: Double) -> BillFrequency? {
            if medianGap >= 6 && medianGap <= 8 { return .weekly }
            if medianGap >= 24 && medianGap <= 37 { return .monthly }
            if medianGap >= 80 && medianGap <= 100 { return .quarterly }
            if medianGap >= 330 && medianGap <= 400 { return .yearly }
            return nil
        }

        func toleranceDays(for freq: BillFrequency) -> Int {
            switch freq {
            case .weekly: return 2
            case .monthly: return 7
            case .quarterly: return 15
            case .yearly: return 30
            }
        }

        func periodDays(for freq: BillFrequency) -> Int {
            switch freq {
            case .weekly: return 7
            case .monthly: return 30
            case .quarterly: return 90
            case .yearly: return 365
            }
        }

        var candidates: [RecurringCandidate] = []
        for (note, items) in groups {
            // Need at least 3 occurrences spanning >= 2 cycles
            guard items.count >= 3 else { continue }

            // Dates
            let dates = items.compactMap { iso.date(from: $0.date) }.sorted()
            guard dates.count >= 3 else { continue }

            // Category-based exclusions unless note matches subscription keywords
            let commonCat = (mostCommon(items.map { $0.category }) ?? "").trimmingCharacters(in: .whitespaces)
            let noteHasSubKeyword = subscriptionKeywords.contains { note.contains($0) }
            if excludeCategories.contains(commonCat) && !noteHasSubKeyword { continue }
            if excludeKeywords.contains(where: { note.contains($0) }) && !noteHasSubKeyword { continue }

            // Amount stability (coefficient of variation <= 0.25)
            let amts = items.map { $0.amount }
            let mean = amts.reduce(0, +) / Double(amts.count)
            guard mean > 0 else { continue }
            let variance = amts.reduce(0) { acc, x in acc + pow(x - mean, 2) } / Double(amts.count)
            let std = sqrt(variance)
            let cv = std / mean
            if cv > 0.25 && !noteHasSubKeyword { continue }

            // Gaps and cadence consistency
            let day: TimeInterval = 24*60*60
            let gaps = zip(dates.dropFirst(), dates).map { Int(round($0.timeIntervalSince($1) / day)) }
            guard !gaps.isEmpty else { continue }
            let medianGap = median(of: gaps.map(Double.init))
            guard let freq = guessFrequency(medianGap) else { continue }
            let tol = toleranceDays(for: freq)
            let withinTol = gaps.filter { abs($0 - Int(round(medianGap))) <= tol }.count
            if Double(withinTol) / Double(gaps.count) < 0.6 { continue }

            // Coverage: span should be >= 2 periods
            let spanDays = Int(dates.last!.timeIntervalSince(dates.first!) / (24*60*60))
            if spanDays < (periodDays(for: freq) * 2 - tol) { continue }

            // Build candidate
            let avgAmount = mean
            let last = dates.last!
            let nextDue = Calendar.current.date(byAdding: freq == .weekly ? .day : .month,
                                                value: freq == .weekly ? 7 : (freq == .monthly ? 1 : (freq == .quarterly ? 3 : 12)),
                                                to: last)
            let prettyName = note.capitalized
            let category = noteHasSubKeyword ? "Subscriptions" : (commonCat.isEmpty ? "Subscriptions" : commonCat)
            candidates.append(RecurringCandidate(name: prettyName,
                                                 averageAmount: avgAmount,
                                                 frequency: freq,
                                                 occurrences: items.count,
                                                 lastSeen: last,
                                                 nextDue: nextDue,
                                                 category: category))
        }

        // Rank by estimated monthly cost (freq-weighted), then occurrences
        func monthlyFactor(_ f: BillFrequency) -> Double {
            switch f {
            case .weekly: return 4.33
            case .monthly: return 1
            case .quarterly: return 1.0/3.0
            case .yearly: return 1.0/12.0
            }
        }
        return candidates.sorted { a, b in
            let am = a.averageAmount * monthlyFactor(a.frequency)
            let bm = b.averageAmount * monthlyFactor(b.frequency)
            if am != bm { return am > bm }
            if a.occurrences != b.occurrences { return a.occurrences > b.occurrences }
            return a.lastSeen > b.lastSeen
        }.prefix(10).map { $0 }
    }

    private func median(of xs: [Double]) -> Double {
        let s = xs.sorted()
        guard !s.isEmpty else { return 0 }
        let mid = s.count / 2
        if s.count % 2 == 0 { return (s[mid-1] + s[mid]) / 2 } else { return s[mid] }
    }

    private func mostCommon<T: Hashable>(_ arr: [T]) -> T? {
        let map = arr.reduce(into: [T:Int]()) { $0[$1, default: 0] += 1 }
        return map.max(by: { $0.value < $1.value })?.key
    }

    private var recurringCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Possible Recurring Bills", systemImage: "repeat")
                    .font(.headline)
                    .foregroundColor(adaptiveTextColor)
                Spacer()
                Text("\(recurringCandidates.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)

            ForEach(recurringCandidates) { c in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.name)
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        Text("$\(c.averageAmount, specifier: "%.2f") • \(c.frequency.rawValue) • \(c.occurrences)x")
                            .font(.subheadline)
                            .foregroundColor(adaptiveSecondaryTextColor)
                    }
                    Spacer()
                    Button("Add Bill") {
                        let bill = RecurringBill(
                            name: c.name,
                            amount: c.averageAmount,
                            frequency: c.frequency,
                            category: c.category,
                            nextDue: c.nextDue,
                            isActive: true,
                            color: .orange
                        )
                        billStorage.addBill(bill)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct InsightCard: View {
    let insight: SpendingInsight
    @Environment(\.colorScheme) var colorScheme
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.white.opacity(0.9)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            VStack {
                Image(systemName: insight.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(insight.category.color)
                
                if insight.actionable {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(insight.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(adaptiveTextColor)
                    
                    Spacer()
                    
                    Text("\(Int(insight.confidence * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(insight.category.color)
                        .cornerRadius(4)
                }
                
                Text(insight.description)
                    .font(.subheadline)
                    .foregroundColor(adaptiveSecondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                
                if insight.actionable {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Actionable")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}
