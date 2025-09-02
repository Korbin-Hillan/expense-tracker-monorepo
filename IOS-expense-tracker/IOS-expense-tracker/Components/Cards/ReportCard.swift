//
//  ReportCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct ReportCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    // Adaptive colors handled by material card style
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(value, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }
}
