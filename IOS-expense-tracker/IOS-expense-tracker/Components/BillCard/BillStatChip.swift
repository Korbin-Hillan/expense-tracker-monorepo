//
//  BillStatChip.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct BillStatChip: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            BillStatChip(count: 5, label: "Pending", color: .orange)
            BillStatChip(count: 12, label: "Paid", color: .green)
            BillStatChip(count: 2, label: "Overdue", color: .red)
        }
    }
}
