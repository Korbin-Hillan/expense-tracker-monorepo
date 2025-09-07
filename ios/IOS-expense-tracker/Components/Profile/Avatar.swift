//
//  Avatar.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct Avatar: View {
    let initial: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.2))

                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
            
            Text(initial)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 120, height: 120)
    }
}
