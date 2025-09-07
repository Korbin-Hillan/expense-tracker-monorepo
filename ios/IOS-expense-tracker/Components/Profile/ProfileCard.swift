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
    @State private var summary: TransactionSummary?
    @State private var isLoadingStats = true

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
                Avatar(initial: initial)
                    .frame(width: 140, height: 140)
                
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

                    if let tz = profile.timezone, !tz.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                            Text(tz)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.15))
                        .cornerRadius(10)
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
                        title: "Total Spent",
                        value: isLoadingStats ? "..." : "$\(String(format: "%.0f", summary?.totalExpenses ?? 0))",
                        icon: "creditcard.fill",
                        color: .red
                    )
                    
                    ProfileStatCard(
                        title: "Transactions",
                        value: isLoadingStats ? "..." : "\(summary?.totalTransactions ?? 0)",
                        icon: "chart.bar.fill",
                        color: .green
                    )
                    
                    ProfileStatCard(
                        title: "Categories Used",
                        value: isLoadingStats ? "..." : "\(summary?.categorySummary.count ?? 0)",
                        icon: "tag.fill",
                        color: .orange
                    )
                    
                    ProfileStatCard(
                        title: "Net Balance",
                        value: isLoadingStats ? "..." : "$\(String(format: "%.0f", summary?.netAmount ?? 0))",
                        icon: summary?.netAmount ?? 0 >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        color: summary?.netAmount ?? 0 >= 0 ? .green : .red
                    )
                }
            }
            
            // Action buttons
            VStack(spacing: 16) {
                // Primary actions
                HStack(spacing: 12) {
                    Button(action: {
                        onRefresh()
                        Task { await loadProfileStats() }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .rotationEffect(.degrees(isLoadingStats ? 360 : 0))
                                .animation(isLoadingStats ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoadingStats)
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

                // Edit Profile action
                EditProfileButton(profile: profile) { updated in
                    // No-op: parent view will refetch on demand
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
        .cardStyle(cornerRadius: 24)
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView(onSignOut: onSignOut)
        }
        .task {
            await loadProfileStats()
        }
    }

    private var initial: String {
        if let n = profile.name?.first { return String(n).uppercased() }
        if let e = profile.email?.first { return String(e).uppercased() }
        return "?"
    }
    
    private func loadProfileStats() async {
        isLoadingStats = true
        
        do {
            let api = TransactionsAPI()
            summary = try await api.getSummary()
            isLoadingStats = false
        } catch {
            print("Failed to load profile stats: \(error)")
            isLoadingStats = false
        }
    }
}

private struct EditProfileButton: View {
    let profile: UserProfile
    var onUpdated: (UserProfile) -> Void
    @State private var showingEdit = false

    var body: some View {
        Button(action: { showingEdit = true }) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Edit Profile")
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
        .sheet(isPresented: $showingEdit) {
            EditProfileSheet(initialProfile: profile) { updated in
                onUpdated(updated)
                showingEdit = false
            }
        }
    }
}
