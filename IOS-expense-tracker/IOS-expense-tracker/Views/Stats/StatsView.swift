//
//  StatsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var analytics = FinancialAnalytics()
    @StateObject private var billStorage = BillStorage.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var transactions: [TransactionDTO] = []
    @State private var isLoadingTransactions = false
    @State private var error: Error?
    @State private var showingAgentChat = false
    @State private var recurringCandidates: [RecurringCandidate] = []
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.white.opacity(0.9)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Financial Insights")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(adaptiveTextColor)
                    
                    Text("AI-powered analysis of your spending patterns")
                        .font(.subheadline)
                        .foregroundColor(adaptiveSecondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Quick Stats Card
                if !transactions.isEmpty {
                    quickStatsCard
                }
                
                // Refresh Button
                Button(action: refreshInsights) {
                    HStack {
                        if analytics.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18))
                        }
                        Text(analytics.isAnalyzing ? "Analyzing..." : "Generate Insights")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(analytics.isAnalyzing ? .gray : .blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(analytics.isAnalyzing || transactions.isEmpty)

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
                    .background(.purple)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(transactions.isEmpty)
                
                // Insights List
                if !analytics.insights.isEmpty {
                    insightsSection
                } else if !transactions.isEmpty && !analytics.isAnalyzing {
                    emptyInsightsView
                } else if transactions.isEmpty && !isLoadingTransactions {
                    noDataView
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
                        .foregroundColor(adaptiveSecondaryTextColor)
                    
                    Text("\(transactions.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(adaptiveTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("This Month")
                        .font(.subheadline)
                        .foregroundColor(adaptiveSecondaryTextColor)
                    
                    Text("$\(monthlySpending, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(adaptiveTextColor)
                }
            }
        }
        .padding(24)
        .background(.white.opacity(0.15))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Insights")
                    .font(.headline)
                    .foregroundColor(adaptiveTextColor)
                
                Spacer()
                
                Text("\(analytics.insights.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(analytics.insights, id: \.id) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
    
    private var emptyInsightsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(adaptiveSecondaryTextColor)
            
            Text("Tap 'Generate Insights'")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            
            Text("AI will analyze your spending patterns and provide personalized insights")
                .font(.subheadline)
                .foregroundColor(adaptiveSecondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(.white.opacity(0.1))
        .cornerRadius(16)
    }

    // Server Insights UI removed
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(adaptiveSecondaryTextColor)
            
            Text("No transaction data")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            
            Text("Add some transactions to see AI-powered insights about your spending")
                .font(.subheadline)
                .foregroundColor(adaptiveSecondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Error loading data")
                .font(.headline)
                .foregroundColor(adaptiveTextColor)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(adaptiveSecondaryTextColor)
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
        .background(.white.opacity(0.1))
        .cornerRadius(16)
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
    
    private func refreshInsights() {
        Task {
            await analytics.analyzeFinancialData(
                transactions: transactions,
                bills: billStorage.bills
            )
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
