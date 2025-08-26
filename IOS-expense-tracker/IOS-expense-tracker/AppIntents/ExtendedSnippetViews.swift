//
//  ExtendedSnippetViews.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/26/25.
//

import SwiftUI

// MARK: - Receipt Snippet View
struct ReceiptSnippetView: View {
    let amount: Double?
    let merchant: String?
    let category: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.orange)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt Ready to Log")
                    .font(.headline)
                
                if let amount = amount {
                    Text("$\(amount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                } else {
                    Text("Amount to be entered")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if let merchant = merchant {
                        Text(merchant)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    if let category = category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Monthly Summary Snippet View
struct MonthlySummarySnippetView: View {
    let totalIncome: Double
    let totalExpenses: Double
    let netAmount: Double
    let topCategory: String?
    let topCategoryAmount: Double
    let transactionCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Summary")
                        .font(.headline)
                    
                    Text("\(transactionCount) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(netAmount >= 0 ? "+$\(netAmount, specifier: "%.2f")" : "-$\(abs(netAmount), specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(netAmount >= 0 ? .green : .red)
                    
                    Text("net")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Income vs Expenses
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("+$\(totalIncome, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("-$\(totalExpenses, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                if let topCategory = topCategory {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 4) {
                        Text("Top Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(topCategory)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("$\(topCategoryAmount, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Visual indicator
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(netAmount >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .frame(height: 6)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Extended Snippet View Previews
#Preview("Receipt Snippet") {
    ReceiptSnippetView(
        amount: 23.45,
        merchant: "Target",
        category: "Groceries"
    )
    .padding()
}

#Preview("Monthly Summary Snippet") {
    MonthlySummarySnippetView(
        totalIncome: 3500.00,
        totalExpenses: 2840.75,
        netAmount: 659.25,
        topCategory: "Groceries",
        topCategoryAmount: 456.78,
        transactionCount: 42
    )
    .padding()
}

#Preview("Monthly Summary Snippet - Over Budget") {
    MonthlySummarySnippetView(
        totalIncome: 3000.00,
        totalExpenses: 3240.50,
        netAmount: -240.50,
        topCategory: "Entertainment",
        topCategoryAmount: 680.25,
        transactionCount: 38
    )
    .padding()
}