//
//  TransactionRowDetailed.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct TransactionRowDetailed: View {
    let transaction: TransactionDTO
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var transactionIcon: String {
        switch transaction.type {
        case "income":
            return "plus.circle.fill"
        case "expense":
            return "minus.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var transactionColor: Color {
        switch transaction.type {
        case "income":
            return .green
        case "expense":
            return .red
        default:
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Transaction icon
            Image(systemName: transactionIcon)
                .font(.system(size: 24))
                .foregroundColor(transactionColor)
                .frame(width: 40, height: 40)
                .background(transactionColor.opacity(0.1))
                .cornerRadius(10)
            
            // Transaction details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(transaction.note ?? transaction.category)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    let signed = transaction.type == "expense" ? -transaction.amount : transaction.amount
                    Text(String(format: "%@$%.2f", signed >= 0 ? "+" : "", signed))
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(transactionColor)
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(transaction.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Palette.info)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Palette.danger)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 16)
        .contentShape(Rectangle())
    }
}
