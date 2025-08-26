//
//  ExtendedAppIntents.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/26/25.
//

import AppIntents
import Foundation

// MARK: - Receipt Logging Intent
struct LogReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Receipt"
    static var description = IntentDescription("Log expenses from a receipt")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log this receipt for \(\.$amount) at \(\.$merchant)")
    }
    
    @Parameter(title: "Receipt Amount", description: "Total amount on the receipt")
    var amount: Double?
    
    @Parameter(title: "Merchant", description: "Store or merchant name")
    var merchant: String?
    
    @Parameter(title: "Category", description: "What type of purchase")
    var category: CategoryEntity?
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let dialogText = if let amount = amount, let merchant = merchant {
            "I'll help you log a receipt for $\(String(format: "%.2f", amount)) from \(merchant). Opening the app to add details."
        } else {
            "I'll help you log that receipt. Opening the app so you can enter the details."
        }
        
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText)
        ) {
            ReceiptSnippetView(
                amount: amount,
                merchant: merchant,
                category: category?.name
            )
        }
    }
}

// MARK: - Quick Grocery Intent
struct QuickGroceryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Grocery Expense"
    static var description = IntentDescription("Quickly log a grocery expense")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Spent \(\.$amount) on groceries at \(\.$store)")
    }
    
    @Parameter(title: "Amount", description: "How much you spent on groceries")
    var amount: Double
    
    @Parameter(title: "Store", description: "Which grocery store")
    var store: String?
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let noteText = store != nil ? "Groceries at \(store!)" : "Groceries"
        
        do {
            let transactionBody = CreateTransactionBody(
                type: "expense",
                amount: amount,
                category: "Groceries",
                note: noteText,
                date: ISO8601DateFormatter().string(from: Date())
            )
            
            let api = TransactionsAPI()
            let transaction = try await api.create(transactionBody)
            
            let dialogText = if let store = store {
                "Logged $\(String(format: "%.2f", amount)) grocery expense at \(store)"
            } else {
                "Logged $\(String(format: "%.2f", amount)) grocery expense"
            }
            
            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                ExpenseSnippetView(
                    amount: amount,
                    category: "Groceries",
                    merchant: store,
                    success: true
                )
            }
        } catch {
            return .result(
                dialog: IntentDialog("Sorry, I couldn't log that grocery expense. Please try again.")
            ) {
                ExpenseSnippetView(
                    amount: amount,
                    category: "Groceries",
                    merchant: store,
                    success: false
                )
            }
        }
    }
}

// MARK: - Quick Coffee Intent
struct QuickCoffeeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Coffee Purchase"
    static var description = IntentDescription("Quickly log a coffee purchase")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Spent \(\.$amount) on coffee at \(\.$coffeeshop)")
    }
    
    @Parameter(title: "Amount", description: "How much you spent on coffee")
    var amount: Double
    
    @Parameter(title: "Coffee Shop", description: "Which coffee shop", default: "Coffee Shop")
    var coffeeshop: String
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let transactionBody = CreateTransactionBody(
                type: "expense",
                amount: amount,
                category: "Coffee",
                note: "Coffee at \(coffeeshop)",
                date: ISO8601DateFormatter().string(from: Date())
            )
            
            let api = TransactionsAPI()
            let transaction = try await api.create(transactionBody)
            
            return .result(
                dialog: IntentDialog("Logged $\(String(format: "%.2f", amount)) coffee purchase at \(coffeeshop)")
            ) {
                ExpenseSnippetView(
                    amount: amount,
                    category: "Coffee",
                    merchant: coffeeshop,
                    success: true
                )
            }
        } catch {
            return .result(
                dialog: IntentDialog("Sorry, I couldn't log that coffee purchase. Please try again.")
            ) {
                ExpenseSnippetView(
                    amount: amount,
                    category: "Coffee",
                    merchant: coffeeshop,
                    success: false
                )
            }
        }
    }
}

// MARK: - Monthly Summary Intent
struct MonthlySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Summary"
    static var description = IntentDescription("Get a summary of this month's spending")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Show my monthly spending summary")
    }
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let api = TransactionsAPI()
            let transactions = try await api.list(limit: 100)
            
            let calendar = Calendar.current
            let now = Date()
            let dateFormatter = ISO8601DateFormatter()
            
            let currentMonthTransactions = transactions.filter { transaction in
                guard let date = dateFormatter.date(from: transaction.date) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            
            let expenses = currentMonthTransactions.filter { $0.type == "expense" }
            let income = currentMonthTransactions.filter { $0.type == "income" }
            
            let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
            let totalIncome = income.reduce(0) { $0 + $1.amount }
            let netAmount = totalIncome - totalExpenses
            
            // Find top category
            let categorySpending = Dictionary(grouping: expenses, by: { $0.category })
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            let topCategory = categorySpending.max(by: { $0.value < $1.value })
            
            let dialogText = "This month: You spent $\(String(format: "%.2f", totalExpenses)) and earned $\(String(format: "%.2f", totalIncome)). " +
            (netAmount >= 0 ? "You're $\(String(format: "%.2f", netAmount)) ahead." : "You're $\(String(format: "%.2f", abs(netAmount))) over budget.") +
            (topCategory != nil ? " Top category: \(topCategory!.key) at $\(String(format: "%.2f", topCategory!.value))." : "")
            
            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                MonthlySummarySnippetView(
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    netAmount: netAmount,
                    topCategory: topCategory?.key,
                    topCategoryAmount: topCategory?.value ?? 0,
                    transactionCount: currentMonthTransactions.count
                )
            }
        } catch {
            return .result(
                dialog: IntentDialog("Sorry, I couldn't retrieve your monthly summary right now.")
            ) {
                MonthlySummarySnippetView(
                    totalIncome: 0,
                    totalExpenses: 0,
                    netAmount: 0,
                    topCategory: nil,
                    topCategoryAmount: 0,
                    transactionCount: 0
                )
            }
        }
    }
}

