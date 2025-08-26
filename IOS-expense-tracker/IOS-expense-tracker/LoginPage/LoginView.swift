//
//  LoginView.swift
//  expense-tracker-mobile
//
//  Created by Claude on 8/24/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecureEntry = true
    @State private var authError: String? = nil
    @State private var isAuthenticating = false
    @State private var rememberMe = false
    
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let onLoginComplete: () -> Void
    let onShowRegistration: () -> Void
    @State private var authClient = AuthClient()
    
    enum Field {
        case email, password
    }
    
    // Adaptive colors
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
    
    private var shouldDisableButton: Bool {
        email.trimmingCharacters(in: .whitespaces).isEmpty || 
        password.isEmpty || 
        isAuthenticating
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: adaptiveBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .contentShape(Rectangle()) // make the whole gradient tappable
                .onTapGesture { focusedField = nil }
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(adaptiveSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Address")
                                .font(.caption)
                                .foregroundColor(adaptiveSecondaryText)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(adaptiveSecondaryText)
                                    .frame(width: 16)
                                
                                TextField("Enter your email", text: $email)
                                    .focused($focusedField, equals: .email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(adaptiveCardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .email ? Color.blue : adaptiveBorderColor,
                                        lineWidth: focusedField == .email ? 2 : 1
                                    )
                            )
                            .cornerRadius(12)
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryText)
                                
                                Spacer()
                                
                                Button {
                                    print("🔄 Forgot password tapped")
                                    // TODO: Implement forgot password flow
                                    authError = "Forgot password feature coming soon!"
                                } label: {
                                    Text("Forgot?")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(adaptiveSecondaryText)
                                    .frame(width: 16)
                                
                                if isSecureEntry {
                                    SecureField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .textContentType(.password)
                                } else {
                                    TextField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .textContentType(.password)
                                }
                                
                                Button {
                                    isSecureEntry.toggle()
                                    print("👁️ Password visibility toggled: \(isSecureEntry ? "hidden" : "visible")")
                                } label: {
                                    Image(systemName: isSecureEntry ? "eye.slash" : "eye")
                                        .foregroundColor(adaptiveSecondaryText)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding()
                            .background(adaptiveCardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .password ? Color.blue : adaptiveBorderColor,
                                        lineWidth: focusedField == .password ? 2 : 1
                                    )
                            )
                            .cornerRadius(12)
                        }
                        
                        // Remember me
                        HStack {
                            Button {
                                rememberMe.toggle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(rememberMe ? .blue : adaptiveSecondaryText)
                                    
                                    Text("Remember me")
                                        .font(.caption)
                                        .foregroundColor(adaptiveSecondaryText)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Error message
                        if let error = authError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Sign in button
                        Button {
                            print("🔘 LoginView: Sign In button tapped!")
                            print("📧 Email: '\(email)' (empty: \(email.isEmpty))")
                            print("🔒 Password length: \(password.count) (empty: \(password.isEmpty))")
                            print("⏳ Is authenticating: \(isAuthenticating)")
                            focusedField = nil // Dismiss keyboard
                            loginUser()
                        } label: {
                            HStack {
                                if isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Signing In...")
                                        .font(.system(size: 16, weight: .semibold))
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: shouldDisableButton ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(shouldDisableButton)
                        .opacity(shouldDisableButton ? 0.6 : 1.0)
                    }
                    
                    Spacer()
                    
                    // Create account option
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(adaptiveBorderColor)
                            
                            Text("or")
                                .font(.caption)
                                .foregroundColor(adaptiveSecondaryText)
                                .padding(.horizontal, 12)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(adaptiveBorderColor)
                        }
                        
                        Button {
                            onShowRegistration()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundColor(adaptiveSecondaryText)
                                Text("Create Account")
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Helper Functions
    
    private func loginUser() {
        print("🔐 LoginView: Starting login process...")
        print("📧 Email: '\(email)'")
        print("🔒 Password length: \(password.count)")
        
        guard !email.isEmpty, !password.isEmpty else {
            print("❌ LoginView: Empty email or password")
            authError = "Please enter both email and password."
            return
        }
        
        print("🔄 LoginView: Setting isAuthenticating to true")
        isAuthenticating = true
        authError = nil
        
        Task {
            do {
                print("📤 LoginView: Calling authClient.loginWithEmail...")
                let response = try await authClient.loginWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                
                await MainActor.run {
                    print("✅ LoginView: Login successful!")
                    print("🎫 Token received: \(response.token.prefix(20))...")
                    print("🔄 Refresh token received: \(response.refresh_token.prefix(20))...")
                    
                    // Tokens should already be saved by AuthClient, but verify
                    if loadToken() == nil {
                        print("⚠️ LoginView: Token not found in Keychain, saving manually")
                        saveToken(response.token)
                        saveRefreshToken(response.refresh_token)
                    }

                    isAuthenticating = false
                    print("🎊 LoginView: Calling onLoginComplete")
                    onLoginComplete()
                }
            } catch {
                await MainActor.run {
                    print("❌ LoginView: Login failed with error: \(error)")
                    print("🐛 Error details: \(String(describing: error))")
                    isAuthenticating = false
                    
                    if let authError = error as? AuthError {
                        self.authError = authError.localizedDescription
                        print("📋 AuthError message: \(authError.localizedDescription)")
                        
                        // If user not found, suggest registration
                        if case .server(let msg) = authError, msg.contains("user_not_found") {
                            self.authError = "Account not found. Please create an account first."
                            print("👤 User not found - suggesting registration")
                        }
                    } else {
                        self.authError = "Login failed: \(error.localizedDescription)"
                        print("📋 Generic error message: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView(
        onLoginComplete: { print("Login completed") },
        onShowRegistration: { print("Show registration") }
    )
}
