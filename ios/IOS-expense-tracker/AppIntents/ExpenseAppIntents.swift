//
//  ExpenseAppIntents.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/26/25.
//

import AppIntents
import Foundation

// MARK: - Entity Definitions
struct ExpenseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Expense"
    static var defaultQuery = ExpenseQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Expense")
    }
}

struct ExpenseQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ExpenseEntity] {
        return identifiers.map { ExpenseEntity(id: $0) }
    }
    
    func suggestedEntities() async throws -> [ExpenseEntity] {
        return []
    }
}

// MARK: - Category Entity
struct CategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = CategoryQuery()
    
    let name: String
    var id: String { name }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CategoryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        return identifiers.map { CategoryEntity(name: $0) }
    }
    
    func suggestedEntities() async throws -> [CategoryEntity] {
        // Common expense categories
        let commonCategories = [
            "Food", "Groceries", "Transportation", "Entertainment", 
            "Shopping", "Bills", "Healthcare", "Education", "Travel",
            "Coffee", "Restaurants", "Gas", "Subscriptions", "Clothing"
        ]
        return commonCategories.map { CategoryEntity(name: $0) }
    }
}

// MARK: - Add Expense Intent
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Log a new expense transaction")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) expense") {
            \.$merchant
            \.$category
            \.$note
        }
    }
    
    mutating func validate() throws {
        guard amount > 0 else {
            throw $amount.needsValueError("Amount must be greater than 0.")
        }
    }
    
    @Parameter(title: "Amount", description: "How much was spent", requestValueDialog: "How much did you spend?")
    var amount: Double
    
    @Parameter(title: "Merchant", description: "Where the money was spent", requestValueDialog: "Where did you spend it?")
    var merchant: String?
    
    @Parameter(title: "Category", description: "Expense category", requestValueDialog: "What category is this expense?")
    var category: CategoryEntity?
    
    @Parameter(title: "Note", description: "Additional details about the expense", requestValueDialog: "Any additional notes?")
    var note: String?
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let categoryName = category?.name ?? "General"
        
        do {
                        
            let dialogText = if let merchant = merchant {
                "Logged $\(String(format: "%.2f", amount)) expense at \(merchant) in \(categoryName)"
            } else {
                "Logged $\(String(format: "%.2f", amount)) expense in \(categoryName)"
            }
            
            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                ExpenseSnippetView(
                    amount: amount,
                    category: categoryName,
                    merchant: merchant,
                    success: true
                )
            }
        }
    }
}

// MARK: - Add Income Intent
struct AddIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Income"
    static var description = IntentDescription("Log a new income transaction")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Earned \(\.$amount) from \(\.$source) for \(\.$category)") {
            \.$note
        }
    }
    
    @Parameter(title: "Amount", description: "How much was earned")
    var amount: Double
    
    @Parameter(title: "Source", description: "Where the income came from")
    var source: String?
    
    @Parameter(title: "Category", description: "Income category")
    var category: String?
    
    @Parameter(title: "Note", description: "Additional details about the income")
    var note: String?
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let categoryName = category ?? source ?? "Income"
        
        do {
            
            let dialogText = if let source = source {
                "Logged $\(String(format: "%.2f", amount)) income from \(source) in \(categoryName)"
            } else {
                "Logged $\(String(format: "%.2f", amount)) income in \(categoryName)"
            }
            
            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                IncomeSnippetView(
                    amount: amount,
                    category: categoryName,
                    source: source,
                    success: true
                )
            }
        }
    }
}

enum TimeframeEnum: String, AppEnum {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Time Frame"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today: "today",
        .week: "this week",
        .month: "this month",
        .year: "this year"
    ]
}


// MARK: - Spending Query Intent
struct SpendingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Spending"
    static var description = IntentDescription("Check spending for a specific category or time period")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Show my \(\.$category) spending \(\.$timeframe)")
    }
    
    @Parameter(title: "Category", description: "Category to check spending for")
    var category: CategoryEntity?
    
    @Parameter(title: "Time Frame", default: .month)
    var timeframe: TimeframeEnum
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let api = TransactionsAPI()
            let transactions = try await api.list(limit: 100)
            
            let expenseTransactions = transactions.filter { $0.type == "expense" }
            let filteredTransactions = filterTransactionsByTimeframe(expenseTransactions, timeframe: timeframe)

            let timeframeText = timeframe.rawValue.lowercased()

            let categoryTransactions = if let category = category {
                filteredTransactions.filter { $0.category.lowercased() == category.name.lowercased() }
            } else {
                filteredTransactions
            }
            
            let totalSpent = categoryTransactions.reduce(0) { $0 + $1.amount }
            let count = categoryTransactions.count
            
            let dialogText = if let category = category {
                "You spent $\(String(format: "%.2f", totalSpent)) on \(category.name.lowercased()) \(timeframeText) across \(count) transactions"
            } else {
                "You spent $\(String(format: "%.2f", totalSpent)) \(timeframeText) across \(count) transactions"
            }

            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                SpendingQuerySnippetView(
                    category: category?.name,
                    timeframe: timeframeText,     // <-- String, not enum
                    amount: totalSpent,
                    transactionCount: count
                )
            }
        } catch {
            let timeframeText = timeframe.rawValue.lowercased()  // <- add this
            return .result(
                dialog: IntentDialog("Sorry, I couldn't retrieve your spending information right now.")
            ) {
                SpendingQuerySnippetView(
                    category: category?.name,
                    timeframe: timeframeText,   // <- use String, not enum
                    amount: 0,
                    transactionCount: 0
                )
            }
        }
    }
    
    private func filterTransactionsByTimeframe(_ transactions: [TransactionDTO], timeframe: TimeframeEnum) -> [TransactionDTO] {
        let calendar = Calendar.current
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        
        return transactions.filter { transaction in
            guard let transactionDate = dateFormatter.date(from: transaction.date) else { return false }
            switch timeframe {
            case .month:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .month)
            case .week:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .weekOfYear)
            case .today:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .day)
            case .year:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .year)
            }
        }
    }
}


// MARK: - Projected Total Intent
struct ProjectedTotalIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Projected Total"
    static var description = IntentDescription("Get projected spending for the month")
    
    static var parameterSummary: some ParameterSummary {
        Summary("What's my projected total for \(\.$timeframe)?")
    }
    
    @Parameter(title: "Time Frame", description: "Time period for projection", default: "this month")
    var timeframe: String
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let api = TransactionsAPI()
            let transactions = try await api.list(limit: 100)
            
            let calendar = Calendar.current
            let now = Date()
            let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            let currentDay = calendar.component(.day, from: now)
            
            let dateFormatter = ISO8601DateFormatter()
            let expenseTransactions = transactions.filter { $0.type == "expense" }
            let currentMonthTransactions = expenseTransactions.filter { transaction in
                guard let date = dateFormatter.date(from: transaction.date) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            
            let currentSpending = currentMonthTransactions.reduce(0) { $0 + $1.amount }
            let dailyAverage = currentDay > 0 ? currentSpending / Double(currentDay) : 0
            let projectedSpending = dailyAverage * Double(daysInMonth)
            
            let dialogText = "Based on your current spending, you're projected to spend $\(String(format: "%.2f", projectedSpending)) this month. You've spent $\(String(format: "%.2f", currentSpending)) so far."
            
            return .result(
                dialog: IntentDialog(stringLiteral: dialogText)
            ) {
                ProjectedTotalSnippetView(
                    currentSpending: currentSpending,
                    projectedTotal: projectedSpending,
                    daysRemaining: daysInMonth - currentDay
                )
            }
        } catch {
            return .result(
                dialog: IntentDialog("Sorry, I couldn't calculate your projected spending right now.")
            ) {
                ProjectedTotalSnippetView(
                    currentSpending: 0,
                    projectedTotal: 0,
                    daysRemaining: 0
                )
            }
        }
    }
}


struct ExpenseAppShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Log expense in \(.applicationName)",
                "Add expense to \(.applicationName)",
                "I spent money using \(.applicationName)",

                // single allowed parameter (CategoryEntity)
                "Log expense for \(\.$category) in \(.applicationName)",
                "Add an expense to \(\.$category) in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Log income in \(.applicationName)",
                "Add income to \(.applicationName)",
                "I earned money in \(.applicationName)"
            ],
            shortTitle: "Log Income",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: SpendingQueryIntent(),
            phrases: [
                "Show my spending in \(.applicationName)",
                "Check spending in \(.applicationName)",
                "How much did I spend in \(.applicationName)",
                "My spending in \(.applicationName)",

                // pick exactly ONE parameter per phrase:
                "Show my \(\.$category) spending in \(.applicationName)",
                "Show my spending for \(\.$timeframe) in \(.applicationName)"
            ],
            shortTitle: "Check Spending",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: ProjectedTotalIntent(),
            phrases: [
                "What's my projected total in \(.applicationName)",
                "Projected spending in \(.applicationName)",
                "Monthly projection in \(.applicationName)",
                "How much will I spend in \(.applicationName)"
            ],
            shortTitle: "Projected Total",
            systemImageName: "chart.line.uptrend.xyaxis"
        )

        AppShortcut(
            intent: LogReceiptIntent(),
            phrases: [
                "Log receipt in \(.applicationName)",
                "Log this receipt in \(.applicationName)",
                "Add receipt to \(.applicationName)",
                "I have a receipt in \(.applicationName)"
            ],
            shortTitle: "Log Receipt",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: QuickGroceryIntent(),
            phrases: [
                "Grocery shopping in \(.applicationName)",
                "Spent on groceries in \(.applicationName)",
                "Log grocery expense in \(.applicationName)",
                "I went grocery shopping in \(.applicationName)"
            ],
            shortTitle: "Log Groceries",
            systemImageName: "cart"
        )

        AppShortcut(
            intent: QuickCoffeeIntent(),
            phrases: [
                "Coffee purchase in \(.applicationName)",
                "Bought coffee in \(.applicationName)",
                "Log coffee in \(.applicationName)",
                "I bought coffee in \(.applicationName)"
            ],
            shortTitle: "Log Coffee",
            systemImageName: "cup.and.saucer"
        )

        AppShortcut(
            intent: MonthlySummaryIntent(),
            phrases: [
                "Monthly summary in \(.applicationName)",
                "How am I doing this month in \(.applicationName)",
                "Show monthly summary in \(.applicationName)",
                "My monthly spending in \(.applicationName)"
            ],
            shortTitle: "Monthly Summary",
            systemImageName: "calendar.badge.checkmark"
        )
    }
}
