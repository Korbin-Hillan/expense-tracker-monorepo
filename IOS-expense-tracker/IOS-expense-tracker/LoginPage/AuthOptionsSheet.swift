//
//  AuthOptionsSheet.swift
//  expense-tracker-mobile
//
//  Created by Korbin Hillan on 8/19/25.
//

import SwiftUI

struct AuthOptionsSheet: View {
    var onApple: () -> Void
    var onGoogle: () -> Void
    var onEmail: (String, String) -> Void
    var onAuthenticated: () -> Void
    var authError: String? = nil
    var isAuthenticating: Bool = false
    @State private var showingRegistrationView = false
    @State private var showingLoginView = false
    @Environment(\.colorScheme) var colorScheme
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecureEntry = true
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    // Adaptive colors based on color scheme
    private var adaptiveBackgroundColors: [Color] {
        colorScheme == .dark ? [
            Color(hex: "#1a1a2e"),
            Color(hex: "#16213e"),
            Color(hex: "#0f3460")
        ] : [
            Color(hex: "#F8FAFC"),
            Color(hex: "#F1F5F9"),
            Color(hex: "#E2E8F0")
        ]
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(hex: "#2a2d3a") : Color.white
    }
    
    private var adaptiveBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#404354") : Color(hex: "#E5E7EB")
    }
    
    private var adaptiveSecondaryText: Color {
        colorScheme == .dark ? Color(hex: "#9ca3af") : Color.secondary
    }
    
    var body: some View {
        ZStack {
            // Adaptive gradient background
            LinearGradient(
                colors: adaptiveBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header with improved typography
                VStack(spacing: 8) {
                    Text("Welcome!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Sign in with your account or we'll create one for you")
                        .font(.subheadline)
                        .foregroundColor(adaptiveSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)
                
                VStack(spacing: 16) {
                    // Apple Sign In with SF Symbols
                    ProviderButton(
                        title: "Continue with Apple",
                        icon: Image(systemName: "apple.logo"),
                        foreground: .white,
                        background: .black,
                        border: .clear,
                        action: onApple
                    )
                    
                    // Google Sign In with adaptive styling
                    ProviderButton(
                        title: "Continue with Google",
                        icon: Image("google"),
                        foreground: colorScheme == .dark ? .white : .black,
                        background: colorScheme == .dark ? Color(hex: "#2a2d3a") : .white,
                        border: adaptiveBorderColor,
                        action: onGoogle
                    )
                    
                    // Divider with improved styling
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(adaptiveBorderColor)
                        
                        Text("or continue with email")
                            .font(.caption)
                            .foregroundColor(adaptiveSecondaryText)
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(adaptiveBorderColor)
                    }
                    .padding(.vertical, 8)
                    
                    // Login Button
                    Button {
                        print("🔘 AuthOptionsSheet: Sign In button tapped!")
                        showingLoginView = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.system(size: 16))
                            
                            Text("Sign In")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(adaptiveCardBackground)
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(adaptiveBorderColor, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Registration Button
                    Button {
                        print("🔘 AuthOptionsSheet: Create Account button tapped!")
                        showingRegistrationView = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                            
                            Text("Create Account")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                }
                
                // Helper text for email authentication
                Text("Choose your preferred authentication method above")
                    .font(.caption)
                    .foregroundColor(adaptiveSecondaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                // Terms and privacy with better formatting
                Text("By continuing, you agree to our [Terms of Service](https://example.com/terms) and [Privacy Policy](https://example.com/privacy).")
                    .font(.caption)
                    .foregroundColor(adaptiveSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            print("🎭 AuthOptionsSheet: Sheet appeared")
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView(
                onLoginComplete: {
                    // Close both sheets and call the main callback
                    showingLoginView = false
                    onAuthenticated()
                },
                onShowRegistration: {
                    showingLoginView = false
                    showingRegistrationView = true
                }
            )
        }
        .sheet(isPresented: $showingRegistrationView) {
            RegistrationView {
                // Close both sheets and call the main callback
                showingRegistrationView = false
                onAuthenticated()
            }
        }
    }
}

struct ProviderButton: View {
    let title: String
    let icon: Image?
    let foreground: Color
    let background: Color
    var border: Color? = nil
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(background)
            .foregroundColor(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(border ?? .clear, lineWidth: 1)
            )
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}


#Preview() {
    AuthOptionsSheet(
        onApple: {},
        onGoogle: {},
        onEmail: { _, _ in },
        onAuthenticated: {},
        authError: nil,
        isAuthenticating: false
    )
}
