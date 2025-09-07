//
//  ProfileDetailRow.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct ProfileDetailRow: View {
    let icon: String
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    private var adaptiveRowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.1)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(12)
        .background(adaptiveRowBackground)
        .cornerRadius(10)
    }
}
