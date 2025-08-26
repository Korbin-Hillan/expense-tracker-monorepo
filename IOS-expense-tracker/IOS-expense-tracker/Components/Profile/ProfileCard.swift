//
//  ProfileCard.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI


struct ProfileCard: View {
    let profile: UserProfile
    var onRefresh: () -> Void
    var onSignOut: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAccountSettings = false

    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.white.opacity(0.9)
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header with Avatar and Info
            VStack(spacing: 20) {
                ZStack {
                    // Gradient background for avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 3)
                        )
                    
                    Text(initial)
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 12) {
                    if let name = profile.name, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(adaptiveTextColor)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let email = profile.email {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                            Text(email)
                                .font(.subheadline)
                        }
                        .foregroundColor(adaptiveSecondaryTextColor)
                    }
                    
                    if let provider = profile.provider {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .font(.caption)
                            Text("via \(provider.capitalized)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(adaptiveSecondaryTextColor)
                    }
                }
            }
            
            // Quick Stats Section
            VStack(spacing: 16) {
                Text("Account Overview")
                    .font(.headline)
                    .foregroundColor(adaptiveTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ProfileStatCard(
                        title: "Member Since",
                        value: "Dec 2024",
                        icon: "calendar",
                        color: .blue
                    )
                    
                    ProfileStatCard(
                        title: "Transactions",
                        value: "156",
                        icon: "chart.bar.fill",
                        color: .green
                    )
                    
                    ProfileStatCard(
                        title: "Categories",
                        value: "12",
                        icon: "tag.fill",
                        color: .orange
                    )
                    
                    ProfileStatCard(
                        title: "Account ID",
                        value: String(profile.id.prefix(6)) + "...",
                        icon: "number",
                        color: .purple
                    )
                }
            }
            
            // Action buttons
            VStack(spacing: 16) {
                // Primary actions
                HStack(spacing: 12) {
                    Button(action: onRefresh) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Refresh")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    Button(action: { showingAccountSettings = true }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Settings")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
                
                // Sign out button
                Button(action: onSignOut) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sign Out")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(28)
        .background(.white.opacity(0.15))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
        }
    }

    private var initial: String {
        if let n = profile.name?.first { return String(n).uppercased() }
        if let e = profile.email?.first { return String(e).uppercased() }
        return "?"
    }
}
