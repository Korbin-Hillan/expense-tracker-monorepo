//
//  TransactionRow.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct TransactionRow: View {
    let transaction: TransactionDTO
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var amount: Double {
        transaction.type == "expense" ? -transaction.amount : transaction.amount
    }
    
    private var icon: String {
        transaction.type == "expense" ? "creditcard.fill" : "banknote.fill"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note ?? transaction.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(transaction.category)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(amount >= 0 ? "+$\(amount, specifier: "%.2f")" : "-$\(abs(amount), specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount >= 0 ? .green : .white)
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            // For now, tapping goes to edit
            onEdit()
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
