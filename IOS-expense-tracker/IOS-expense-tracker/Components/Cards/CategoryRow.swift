//
//  CategoryRow.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct CategoryRow: View {
    let item: (category: String, amount: Double)
    let total: Double
    @Environment(\.colorScheme) var colorScheme
    
    private var percentage: Double {
        total > 0 ? (item.amount / total) * 100 : 0
    }
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(adaptiveTextColor)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(item.amount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(adaptiveTextColor)
                    
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: percentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 1.5)
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}
