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
        let gradientColors: [Color]
        
        switch screen {
        case .Home:
            gradientColors = colorScheme == .dark ? [
                Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")
            ] : [
                Color(hex: "#667eea"), Color(hex: "#764ba2")
            ]
        case .Stats:
            gradientColors = colorScheme == .dark ? [
                Color(hex: "#2d1b69"), Color(hex: "#11998e")
            ] : [
                Color(hex: "#f093fb"), Color(hex: "#f5576c")
            ]
        case .Bills:
            gradientColors = colorScheme == .dark ? [
                Color(hex: "#0c4a6e"), Color(hex: "#075985")
            ] : [
                Color(hex: "#4facfe"), Color(hex: "#00f2fe")
            ]
        case .Recent:
            gradientColors = colorScheme == .dark ? [
                Color(hex: "#064e3b"), Color(hex: "#047857")
            ] : [
                Color(hex: "#43e97b"), Color(hex: "#38f9d7")
            ]
        case .Profile:
            gradientColors = colorScheme == .dark ? [
                Color(hex: "#7c2d12"), Color(hex: "#dc2626")
            ] : [
                Color(hex: "#fa709a"), Color(hex: "#fee140")
            ]
        }
        
        return LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
