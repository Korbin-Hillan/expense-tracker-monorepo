//
//  IntentSnippetViews.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/26/25.
//

import SwiftUI
import AppIntents

// MARK: - Expense Snippet View
struct ExpenseSnippetView: View {
    let amount: Double
    let category: String
    let merchant: String?
    let success: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(success ? .green : .red)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(success ? "Expense Logged" : "Failed to Log")
                    .font(.headline)
                    .foregroundColor(success ? .primary : .red)
                
                HStack {
                    Text("$\(amount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        if let merchant = merchant {
                            Text(merchant)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Income Snippet View
struct IncomeSnippetView: View {
    let amount: Double
    let category: String
    let source: String?
    let success: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(success ? .green : .red)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(success ? "Income Logged" : "Failed to Log")
                    .font(.headline)
                    .foregroundColor(success ? .primary : .red)
                
                HStack {
                    Text("+$\(amount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        
                        if let source = source {
                            Text(source)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Spending Query Snippet View
struct SpendingQuerySnippetView: View {
    let category: String?
    let timeframe: String
    let amount: Double
    let transactionCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    if let category = category {
                        Text("\(category.capitalized) Spending")
                            .font(.headline)
                    } else {
                        Text("Total Spending")
                            .font(.headline)
                    }
                    
                    Text(timeframe.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(amount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(amount > 0 ? .primary : .secondary)
                    
                    Text("\(transactionCount) transactions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if amount > 0 {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 6)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Projected Total Snippet View
struct ProjectedTotalSnippetView: View {
    let currentSpending: Double
    let projectedTotal: Double
    let daysRemaining: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Projection")
                        .font(.headline)
                    
                    Text("\(daysRemaining) days remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(projectedTotal, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("projected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(currentSpending, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Projected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(projectedTotal, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.opacity(0.7))
                        .frame(
                            width: projectedTotal > 0 ? min(geometry.size.width * (currentSpending / projectedTotal), geometry.size.width) : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Snippet View Previews
#Preview("Expense Snippet") {
    ExpenseSnippetView(
        amount: 14.56,
        category: "Coffee",
        merchant: "Starbucks",
        success: true
    )
    .padding()
}

#Preview("Income Snippet") {
    IncomeSnippetView(
        amount: 656.52,
        category: "Salary",
        source: "KUIU",
        success: true
    )
    .padding()
}

#Preview("Spending Query Snippet") {
    SpendingQuerySnippetView(
        category: "Groceries",
        timeframe: "this month",
        amount: 234.56,
        transactionCount: 8
    )
    .padding()
}

#Preview("Projected Total Snippet") {
    ProjectedTotalSnippetView(
        currentSpending: 450.75,
        projectedTotal: 1200.00,
        daysRemaining: 15
    )
    .padding()
}