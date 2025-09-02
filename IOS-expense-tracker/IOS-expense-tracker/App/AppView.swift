//
//  AppView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct AppView: View {
    @State private var screen: Screen = .Home
    @Environment(\.colorScheme) var colorScheme
    var onSignOut: () -> Void = {}
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background based on current screen
                backgroundGradient(for: screen)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main content area
                    ZStack {
                        switch screen {
                        case .Home:
                            HomeView()
                        case .Stats:
                            StatsView()
                        case .Bills:
                            BillsView()
                        case .Recent:
                            RecentView()
                        case .Profile:
                            ProfileView(onSignOut: onSignOut)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom navigation bar
                    HomeNavBar(screen: $screen)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
    }
    
    private func backgroundGradient(for screen: Screen) -> LinearGradient {
        // Brand-driven gradients per screen, adaptive to light/dark
        let a = Palette.accent(for: colorScheme)
        let b = Palette.accentSecondary(for: colorScheme)
        let success = Palette.success
        let warn = Palette.warning
        let info = Palette.info
        let danger = Palette.danger

        let gradientColors: [Color]
        switch screen {
        case .Home:
            // Primary brand look
            gradientColors = [a, b]
        case .Stats:
            // Insightful cool tones
            gradientColors = [b, info]
        case .Bills:
            // Financial utilities feel
            gradientColors = [info, a]
        case .Recent:
            // Activity freshness
            gradientColors = [success, b]
        case .Profile:
            // Warm personal area
            gradientColors = [warn, danger]
        }

        return LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
