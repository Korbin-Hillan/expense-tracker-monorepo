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
                
                // Insights List
                if !analytics.insights.isEmpty {
                    insightsSection
                } else if !transactions.isEmpty && !analytics.isAnalyzing {
                    emptyInsightsView
                } else if transactions.isEmpty && !isLoadingTransactions {
                    noDataView
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
