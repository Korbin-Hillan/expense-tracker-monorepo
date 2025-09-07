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
    
    // Use system adaptive colors inside material cards
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(item.amount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: percentage, total: 100)
                .tint(Palette.info)
                .padding(.top, 2)
        }
        .padding(16)
        .cardStyle(cornerRadius: 10)
    }
}
