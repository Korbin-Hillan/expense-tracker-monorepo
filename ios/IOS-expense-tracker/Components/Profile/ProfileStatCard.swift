//
//  ProfileStatCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .cardStyle(cornerRadius: 12)
    }
}
