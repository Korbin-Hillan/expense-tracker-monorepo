//
//  HomeNavBar.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

// Enhanced Navigation Bar
private struct NavTile: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: 64, height: 52) // slightly larger for hit target
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Palette.accent(for: colorScheme).opacity(0.16) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Palette.accent(for: colorScheme).opacity(0.3) : .clear, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(Palette.accent(for: colorScheme))
                        .frame(width: 28, height: 3)
                        .offset(y: 6)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct HomeNavBar: View {
    @Binding var screen: Screen
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtle separator
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                NavTile(
                    systemName: "house.fill",
                    title: "Home",
                    isSelected: screen == .Home
                ) { screen = .Home }
                
                Spacer()
                
                NavTile(
                    systemName: "chart.bar.fill",
                    title: "Stats",
                    isSelected: screen == .Stats
                ) { screen = .Stats }
                
                Spacer()
                
                NavTile(
                    systemName: "creditcard.fill",
                    title: "Bills",
                    isSelected: screen == .Bills
                ) { screen = .Bills }
                
                Spacer()
                
                NavTile(
                    systemName: "clock.fill",
                    title: "Recent",
                    isSelected: screen == .Recent
                ) { screen = .Recent }
                
                Spacer()
                
                NavTile(
                    systemName: "person.crop.circle.fill",
                    title: "Profile",
                    isSelected: screen == .Profile
                ) { screen = .Profile }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }
}
