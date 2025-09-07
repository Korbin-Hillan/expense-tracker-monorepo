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
        HStack(spacing: 8) {
            Text("\(count)")
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(minHeight: 32)
        .padding(.horizontal, 12)
        .cardStyle(cornerRadius: 12)
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
