//
//  LoadingCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


// Enhanced subviews with better styling
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.primary)
            
            VStack(spacing: 8) {
                Text("Loading your profile")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Just a moment while we fetch your details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .cardStyle(cornerRadius: 20)
    }
}
