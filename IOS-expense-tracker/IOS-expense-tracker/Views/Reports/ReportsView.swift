//
//  ReportsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTimeframe: TimeFrame = .month
    @State private var transactions: [TransactionDTO] = []
    @State private var loading = true
    @State private var showingExportSheet = false
    @StateObject private var billStorage = BillStorage.shared
    private let api = TransactionsAPI()
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
    }
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time frame selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Period")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                                    Button(action: { selectedTimeframe = timeframe }) {
                                        Text(timeframe.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedTimeframe == timeframe ? .blue : adaptiveCardBackground)
                                            .foregroundColor(selectedTimeframe == timeframe ? .white : adaptiveTextColor)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Summary Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ReportCard(
                            title: "Total Income",
                            value: totalIncome,
                            icon: "plus.circle.fill",
                            color: .green
                        )
                        
                        ReportCard(
                            title: "Total Expenses",
                            value: totalExpenses,
                            icon: "minus.circle.fill",
                            color: .red
                        )
                        
                        ReportCard(
                            title: "Recurring Bills",
                            value: totalBillsForTimeframe,
                            icon: "calendar.badge.minus",
                            color: .orange
                        )
                        
                        ReportCard(
                            title: "Net Income",
                            value: totalIncome - totalExpenses - totalBillsForTimeframe,
                            icon: "equal.circle.fill",
                            color: (totalIncome - totalExpenses - totalBillsForTimeframe) >= 0 ? .green : .red
                        )
                        
                        ReportCard(
                            title: "Avg Daily Spending",
                            value: averageDailySpending,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )
                        
                        ReportCard(
                            title: "Total Outgoing",
                            value: totalExpenses + totalBillsForTimeframe,
                            icon: "arrow.down.circle.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Category Breakdown
                    if !categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Category Breakdown")
                                .font(.headline)
                                .foregroundColor(adaptiveTextColor)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(categoryBreakdown.prefix(5), id: \.category) { item in
                                    CategoryRow(item: item, total: totalExpenses)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Bills Breakdown
                    if !billsBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recurring Bills Breakdown")
                                .font(.headline)
                                .foregroundColor(adaptiveTextColor)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(billsBreakdown, id: \.category) { item in
                                    CategoryRow(item: item, total: totalBillsForTimeframe)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Financial Reports")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataSheet()
        }
        .task { await loadTransactions() }
        .onChange(of: selectedTimeframe) { _ in
            Task { await loadTransactions() }
        }
    }
    
    private var totalIncome: Double {
        transactions.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpenses: Double {
        transactions.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
    }
    
    private var averageDailySpending: Double {
        let days = dayCountForTimeframe()
        return days > 0 ? totalExpenses / Double(days) : 0
    }
    
    private var categoryBreakdown: [(category: String, amount: Double)] {
        let expenses = transactions.filter { $0.type == "expense" }
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    // Bills calculations based on selected timeframe
    private var totalBillsForTimeframe: Double {
        let activeBills = billStorage.bills.filter { $0.isActive }
        return activeBills.reduce(0) { total, bill in
            let multiplier = billMultiplierForTimeframe(bill.frequency)
            return total + (bill.amount * multiplier)
        }
    }
    
    private var billsBreakdown: [(category: String, amount: Double)] {
        let activeBills = billStorage.bills.filter { $0.isActive }
        return activeBills.map { bill in
            let multiplier = billMultiplierForTimeframe(bill.frequency)
            return (category: "\(bill.name) (\(bill.frequency.rawValue))", amount: bill.amount * multiplier)
        }.sorted { $0.amount > $1.amount }
    }
    
    private func billMultiplierForTimeframe(_ frequency: BillFrequency) -> Double {
        switch selectedTimeframe {
        case .week:
            switch frequency {
            case .weekly: return 1
            case .monthly: return 1.0 / 4.33 // Convert monthly to weekly
            case .quarterly: return 1.0 / 13 // Convert quarterly to weekly
            case .yearly: return 1.0 / 52 // Convert yearly to weekly
            }
        case .month:
            switch frequency {
            case .weekly: return 4.33 // Average weeks per month
            case .monthly: return 1
            case .quarterly: return 1.0 / 3 // Convert quarterly to monthly
            case .yearly: return 1.0 / 12 // Convert yearly to monthly
            }
        case .threeMonths:
            switch frequency {
            case .weekly: return 13 // Weeks in 3 months
            case .monthly: return 3
            case .quarterly: return 1
            case .yearly: return 0.25 // Quarter of year
            }
        case .year:
            switch frequency {
            case .weekly: return 52
            case .monthly: return 12
            case .quarterly: return 4
            case .yearly: return 1
            }
        }
    }
    
    private func dayCountForTimeframe() -> Int {
        switch selectedTimeframe {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        }
    }
    
    private func loadTransactions() async {
        loading = true
        do {
            let limit = selectedTimeframe == .year ? 1000 : 500
            transactions = try await api.list(limit: limit, skip: 0)
        } catch {
            print("Failed to load transactions for reports:", error.localizedDescription)
        }
        loading = false
    }
}
