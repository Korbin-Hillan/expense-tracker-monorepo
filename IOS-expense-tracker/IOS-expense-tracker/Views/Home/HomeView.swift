//
//  HomeView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct HomeView: View {
    @State private var totalBalance: Double = 0.0
    @State private var monthlySpent: Double = 0.0
    @State private var monthlyBudget: Double = UserDefaults.standard.double(forKey: "monthlyBudget") == 0 ? 2500.00 : UserDefaults.standard.double(forKey: "monthlyBudget")
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    @State private var showingReports = false
    @State private var showingSetBudget = false
    @State private var recent: [TransactionDTO] = []
    @State private var allTransactions: [TransactionDTO] = []
    @StateObject private var billStorage = BillStorage.shared
    private let api = TransactionsAPI()
    
    // Adaptive colors for better contrast
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.white.opacity(0.9)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.15)
    }
    
    private var adaptiveProgressTint: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : .white
    }
    
    private var budgetProgressColor: Color {
        let percentage = monthlyBudget > 0 ? monthlySpent / monthlyBudget : 0
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else if percentage >= 0.6 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var budgetStatusIcon: String {
        let percentage = monthlyBudget > 0 ? monthlySpent / monthlyBudget : 0
        if percentage >= 1.0 {
            return "exclamationmark.triangle.fill"
        } else if percentage >= 0.8 {
            return "exclamationmark.circle.fill"
        } else if percentage >= 0.6 {
            return "info.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(adaptiveTextColor)
                    
                    Text("Here's your financial overview")
                        .font(.subheadline)
                        .foregroundColor(adaptiveSecondaryTextColor)
                }
                .padding(.top, 20)
                
                // Balance Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Total Balance")
                                    .font(.subheadline)
                                    .foregroundColor(adaptiveSecondaryTextColor)
                                
                                if !billStorage.bills.isEmpty {
                                    Image(systemName: "calendar.badge.minus")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text("$\(totalBalance, specifier: "%.2f")")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(adaptiveTextColor)
                            
                            if !billStorage.bills.isEmpty {
                                Text("Includes recurring bills")
                                    .font(.caption2)
                                    .foregroundColor(adaptiveSecondaryTextColor.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(adaptiveSecondaryTextColor)
                    }
                    
                    // Monthly spending progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                Text("Monthly Spending")
                                    .font(.subheadline)
                                    .foregroundColor(adaptiveSecondaryTextColor)
                                
                                Image(systemName: budgetStatusIcon)
                                    .font(.system(size: 12))
                                    .foregroundColor(budgetProgressColor)
                            }
                            
                            Spacer()
                            
                            Text("$\(monthlySpent, specifier: "%.0f") / $\(monthlyBudget, specifier: "%.0f")")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(adaptiveTextColor)
                        }
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(budgetProgressColor)
                                .frame(width: max(0, min(1, monthlySpent / monthlyBudget)) * UIScreen.main.bounds.width * 0.7, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: monthlySpent)
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
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)
                        .foregroundColor(adaptiveTextColor)
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        QuickActionCard(
                            title: "Add Expense",
                            icon: "minus.circle.fill",
                            color: .red,
                            action: { showingAddExpense = true }
                        )
                        
                        QuickActionCard(
                            title: "Add Income",
                            icon: "plus.circle.fill",
                            color: .green,
                            action: { showingAddIncome = true }
                        )
                        
                        QuickActionCard(
                            title: "View Reports",
                            icon: "chart.bar.fill",
                            color: .blue,
                            action: { showingReports = true }
                        )
                        
                        QuickActionCard(
                            title: "Set Budget",
                            icon: "target",
                            color: .orange,
                            action: { showingSetBudget = true }
                        )
                    }
                }
                
                // Recent Transactions Preview
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Transactions")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        Spacer()
                        
                        Button("View All") {
                            NotificationCenter.default.post(name: .goToRecentTab, object: nil)
                        }
                            .font(.subheadline)
                            .foregroundColor(adaptiveSecondaryTextColor)
                    }
                    .padding(.horizontal, 4)
                    
                    if recent.isEmpty {
                        Text("No recent transactions yet")
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 4)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(recent.prefix(3)) { t in
                                TransactionRow(
                                    transaction: t,
                                    onEdit: {
                                        // TODO: Handle edit from home screen
                                    },
                                    onDelete: {
                                        deleteTransactionFromHome(t)
                                    }
                                )
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100) // Space for navigation bar
            }
            .padding(.horizontal, 20)
        }
        .task { await loadRecent() }
        .onReceive(billStorage.$bills) { _ in
            // Recalculate balance when bills change
            calculateBalances()
        }
        .sheet(isPresented: $showingAddExpense) {
            AddTransactionSheet(kind: .expense) { _ in
                Task {
                    await loadRecent()
                }
            }
        }
        .sheet(isPresented: $showingAddIncome) {
            AddTransactionSheet(kind: .income) { _ in
                Task {
                    await loadRecent()
                }
            }
        }
        .sheet(isPresented: $showingReports) {
            ReportsView()
        }
        .sheet(isPresented: $showingSetBudget) {
            SetBudgetView(currentBudget: $monthlyBudget)
        }
    }
    
    private func loadRecent() async {
        do {
            recent = try await api.list(limit: 10, skip: 0)
            allTransactions = try await api.list(limit: 1000, skip: 0)
            calculateBalances()
        } catch {
            print("failed to load recent:", error.localizedDescription)
        }
    }
    
    private func deleteTransactionFromHome(_ transaction: TransactionDTO) {
        print("🗑️ HomeView: Starting delete process for transaction: \(transaction.id)")
        
        // Remove from local arrays immediately for UI responsiveness
        recent.removeAll { $0.id == transaction.id }
        allTransactions.removeAll { $0.id == transaction.id }
        calculateBalances()
        print("📱 HomeView: Removed transaction from local UI and recalculated balances")
        
        Task {
            do {
                print("🌐 HomeView: Calling API delete for transaction: \(transaction.id)")
                try await api.delete(transaction.id)
                print("✅ HomeView: Successfully deleted transaction from server: \(transaction.id)")
            } catch {
                print("❌ HomeView: Failed to delete transaction from server: \(error)")
                // Re-add transaction if deletion fails
                await MainActor.run {
                    recent.append(transaction)
                    allTransactions.append(transaction)
                    calculateBalances()
                    print("🔄 HomeView: Re-added transaction to UI due to server error")
                }
            }
        }
    }
    
    private func calculateBalances() {
        // Calculate balance from transactions
        let transactionBalance = allTransactions.reduce(0) { total, transaction in
            return transaction.type == "income" ? total + transaction.amount : total - transaction.amount
        }
        
        // Calculate the annual impact of recurring bills for reference
        let annualBillsTotal = billStorage.bills.reduce(0) { total, bill in
            guard bill.isActive else { return total }
            switch bill.frequency {
            case .weekly: return total + (bill.amount * 52)
            case .monthly: return total + (bill.amount * 12)
            case .quarterly: return total + (bill.amount * 4)
            case .yearly: return total + bill.amount
            }
        }
        
        // Calculate current monthly bills impact
        let monthlyBillsTotal = billStorage.bills.reduce(0) { total, bill in
            guard bill.isActive else { return total }
            switch bill.frequency {
            case .weekly: return total + (bill.amount * 4.33) // Average weeks per month
            case .monthly: return total + bill.amount
            case .quarterly: return total + (bill.amount / 3)
            case .yearly: return total + (bill.amount / 12)
            }
        }
        
        // Total balance = actual transactions minus current month's bill obligations
        totalBalance = transactionBalance - monthlyBillsTotal
        
        // Calculate monthly spending including bills
        let transactionMonthlySpent = allTransactions.filter { transaction in
            return transaction.type == "expense"
        }.reduce(0) { $0 + $1.amount }
        
        monthlySpent = transactionMonthlySpent + monthlyBillsTotal
        
        print("💰 Balance calculation:")
        print("   Transaction balance: $\(transactionBalance)")
        print("   Monthly bills total: $\(monthlyBillsTotal)")
        print("   Final balance (transactions - monthly bills): $\(totalBalance)")
        print("   Monthly spent (transactions): $\(transactionMonthlySpent)")
        print("   Total monthly spent: $\(monthlySpent)")
    }
}
