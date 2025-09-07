//
//  FinancialAnalytics.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/26/25.
//

import CoreML
import Foundation
import SwiftUI

// MARK: - Analytics Models
struct SpendingInsight {
    let id = UUID()
    let title: String
    let description: String
    let category: InsightCategory
    let confidence: Double
    let actionable: Bool
}

enum InsightCategory {
    case pattern, anomaly, prediction, optimization
    
    var icon: String {
        switch self {
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle"
        case .prediction: return "sparkles"
        case .optimization: return "lightbulb"
        }
    }
    
    var color: Color {
        switch self {
        case .pattern: return .blue
        case .anomaly: return .orange
        case .prediction: return .purple
        case .optimization: return .green
        }
    }
}

// MARK: - Analytics Engine
@MainActor
class FinancialAnalytics: ObservableObject {
    @Published var insights: [SpendingInsight] = []
    @Published var isAnalyzing = false
    
    private let patternDetector = SpendingPatternDetector()
    private let anomalyDetector = AnomalyDetector()
    private let forecastEngine = SpendingForecast()
    
    func analyzeFinancialData(transactions: [TransactionDTO], bills: [RecurringBill]) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        print("🔍 Starting analysis with \(transactions.count) transactions")
        print("📈 Transaction breakdown:")
        let expenseCount = transactions.filter { $0.type == "expense" }.count
        let incomeCount = transactions.filter { $0.type == "income" }.count
        print("   - Expenses: \(expenseCount)")
        print("   - Income: \(incomeCount)")
        
        var newInsights: [SpendingInsight] = []
        
        // 1. Pattern Analysis
        let patterns = await patternDetector.detectPatterns(from: transactions)
        newInsights.append(contentsOf: patterns)
        
        // 2. Anomaly Detection
        let anomalies = await anomalyDetector.detectAnomalies(in: transactions)
        newInsights.append(contentsOf: anomalies)
        
        // 3. Spending Forecasts
        let forecasts = await forecastEngine.generateForecasts(transactions: transactions, bills: bills)
        newInsights.append(contentsOf: forecasts)
        
        // 4. Optimization Suggestions
        let optimizations = generateOptimizationSuggestions(transactions: transactions, bills: bills)
        newInsights.append(contentsOf: optimizations)
        
        insights = newInsights.sorted { $0.confidence > $1.confidence }
    }
    
    private func generateOptimizationSuggestions(transactions: [TransactionDTO], bills: [RecurringBill]) -> [SpendingInsight] {
        var suggestions: [SpendingInsight] = []
        
        // Calculate category spending (expenses only)
        let expenseTransactions = transactions.filter { $0.type == "expense" }
        let categorySpending = Dictionary(grouping: expenseTransactions) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        // Find highest spending categories
        if let topCategory = categorySpending.max(by: { $0.value < $1.value }) {
            suggestions.append(SpendingInsight(
                title: "Top Spending Category",
                description: "Your highest expense category is '\(topCategory.key)' at $\(String(format: "%.2f", topCategory.value)). Consider setting a monthly budget for this category.",
                category: .optimization,
                confidence: 0.9,
                actionable: true
            ))
        }
        
        // Check for subscription optimization
        let subscriptionBills = bills.filter { $0.category == "Subscriptions" }
        if subscriptionBills.count > 3 {
            let totalSubscriptions = subscriptionBills.reduce(0) { $0 + $1.amount }
            suggestions.append(SpendingInsight(
                title: "Subscription Review",
                description: "You have \(subscriptionBills.count) active subscriptions costing $\(String(format: "%.2f", totalSubscriptions))/month. Review which ones you actively use.",
                category: .optimization,
                confidence: 0.8,
                actionable: true
            ))
        }
        
        return suggestions
    }
}

// MARK: - Pattern Detection
class SpendingPatternDetector {
    func detectPatterns(from transactions: [TransactionDTO]) async -> [SpendingInsight] {
        var patterns: [SpendingInsight] = []
        
        // Weekly pattern analysis
        let weeklyPatterns = analyzeWeeklyPatterns(transactions)
        patterns.append(contentsOf: weeklyPatterns)
        
        // Category trends
        let categoryTrends = analyzeCategoryTrends(transactions)
        patterns.append(contentsOf: categoryTrends)
        
        return patterns
    }
    
    private func analyzeWeeklyPatterns(_ transactions: [TransactionDTO]) -> [SpendingInsight] {
        let dateFormatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        
        // Group by day of week (expenses only)
        let expenseTransactions = transactions.filter { $0.type == "expense" }
        let daySpending = expenseTransactions.compactMap { transaction -> (Int, Double)? in
            guard let date = dateFormatter.date(from: transaction.date) else { return nil }
            let dayOfWeek = calendar.component(.weekday, from: date)
            return (dayOfWeek, transaction.amount)
        }
        
        let weeklyTotals = Dictionary(grouping: daySpending, by: { $0.0 })
            .mapValues { $0.reduce(0) { $0 + $1.1 } }
        
        if let maxDay = weeklyTotals.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[maxDay.key - 1]
            return [SpendingInsight(
                title: "Weekly Pattern",
                description: "You spend the most on \(dayName)s with an average of $\(String(format: "%.2f", maxDay.value))",
                category: .pattern,
                confidence: 0.75,
                actionable: false
            )]
        }
        
        return []
    }
    
    private func analyzeCategoryTrends(_ transactions: [TransactionDTO]) -> [SpendingInsight] {
        let expenseTransactions = transactions.filter { $0.type == "expense" }
        let categorySpending = Dictionary(grouping: expenseTransactions, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        guard let topCategory = categorySpending.max(by: { $0.value < $1.value }) else {
            return []
        }
        
        let totalSpending = categorySpending.values.reduce(0, +)
        let percentage = (topCategory.value / totalSpending) * 100
        
        return [SpendingInsight(
            title: "Category Trend",
            description: "\(String(format: "%.1f", percentage))% of your spending goes to \(topCategory.key)",
            category: .pattern,
            confidence: 0.8,
            actionable: false
        )]
    }
}

// MARK: - Anomaly Detection
class AnomalyDetector {
    func detectAnomalies(in transactions: [TransactionDTO]) async -> [SpendingInsight] {
        var anomalies: [SpendingInsight] = []
        
        // Amount-based anomalies
        let amountAnomalies = detectAmountAnomalies(transactions)
        anomalies.append(contentsOf: amountAnomalies)
        
        return anomalies
    }
    
    private func detectAmountAnomalies(_ transactions: [TransactionDTO]) -> [SpendingInsight] {
        let expenseTransactions = transactions.filter { $0.type == "expense" }
        let amounts = expenseTransactions.map { $0.amount }
        guard !amounts.isEmpty else { return [] }
        
        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(amounts.count)
        let stdDev = sqrt(variance)
        
        let threshold = mean + (2 * stdDev) // 2 standard deviations
        
        let outliers = expenseTransactions.filter { $0.amount > threshold }
        
        return outliers.map { transaction in
            SpendingInsight(
                title: "Unusual Transaction",
                description: "$\(String(format: "%.2f", transaction.amount)) in \(transaction.category) is unusually high for you",
                category: .anomaly,
                confidence: 0.7,
                actionable: false
            )
        }
    }
}

// MARK: - Spending Forecast
class SpendingForecast {
    func generateForecasts(transactions: [TransactionDTO], bills: [RecurringBill]) async -> [SpendingInsight] {
        var forecasts: [SpendingInsight] = []
        
        // Monthly spending forecast
        let monthlyForecast = predictMonthlySpending(transactions, bills)
        forecasts.append(monthlyForecast)
        
        return forecasts
    }
    
    private func predictMonthlySpending(_ transactions: [TransactionDTO], _ bills: [RecurringBill]) -> SpendingInsight {
        let calendar = Calendar.current
        let now = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        
        // Calculate current month spending (expenses only)
        let dateFormatter = ISO8601DateFormatter()
        let expenseTransactions = transactions.filter { $0.type == "expense" }
        let currentMonthTransactions = expenseTransactions.filter { transaction in
            guard let date = dateFormatter.date(from: transaction.date) else { 
                print("⚠️ Failed to parse date: \(transaction.date)")
                return false 
            }
            let isCurrentMonth = calendar.isDate(date, equalTo: now, toGranularity: .month)
            print("📅 Transaction date: \(transaction.date) -> \(date) -> current month: \(isCurrentMonth)")
            return isCurrentMonth
        }
        
        let currentSpending = currentMonthTransactions.reduce(0) { $0 + $1.amount }
        print("💰 Current month spending: $\(currentSpending) from \(currentMonthTransactions.count) transactions")
        print("📊 Current day: \(currentDay), Days in month: \(daysInMonth)")
        
        let dailyAverage = currentDay > 0 ? currentSpending / Double(currentDay) : 0
        let projectedSpending = dailyAverage * Double(daysInMonth)
        
        // Add recurring bills
        let monthlyBills = bills.reduce(0) { total, bill in
            switch bill.frequency {
            case .monthly: return total + bill.amount
            case .weekly: return total + (bill.amount * 4.33)
            case .quarterly: return total + (bill.amount / 3)
            case .yearly: return total + (bill.amount / 12)
            }
        }
        
        let totalProjected = projectedSpending + monthlyBills
        
        return SpendingInsight(
            title: "Monthly Forecast",
            description: "Based on current spending, you're projected to spend $\(String(format: "%.2f", totalProjected)) this month",
            category: .prediction,
            confidence: 0.85,
            actionable: true
        )
    }
}
