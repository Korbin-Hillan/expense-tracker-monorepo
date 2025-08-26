//
//  BillCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct BillCard: View {
    let bill: RecurringBill
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var daysUntilDue: Int? {
        guard let nextDue = bill.nextDue else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDue).day
    }
    
    private var dueStatus: (text: String, color: Color) {
        guard let days = daysUntilDue else { return ("No due date", .gray) }
        
        if days < 0 {
            return ("\(abs(days)) days overdue", .red)
        } else if days == 0 {
            return ("Due today", .orange)
        } else if days <= 7 {
            return ("Due in \(days) day\(days == 1 ? "" : "s")", .orange)
        } else {
            return ("Due in \(days) days", .green)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Color indicator and icon
            VStack {
                Circle()
                    .fill(bill.color)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(bill.color.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            // Bill info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bill.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(adaptiveTextColor)
                        
                        Text(bill.category)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(bill.amount, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(adaptiveTextColor)
                        
                        Text(bill.frequency.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(dueStatus.color)
                            .frame(width: 8, height: 8)
                        
                        Text(dueStatus.text)
                            .font(.caption)
                            .foregroundColor(dueStatus.color)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                        }
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
