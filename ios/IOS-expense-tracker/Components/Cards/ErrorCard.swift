//
//  ErrorCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct ErrorCard: View {
    let message: String
    var onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .cardStyle(cornerRadius: 20)
    }
}
