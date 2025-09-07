//
//  RegistrationView.swift
//  expense-tracker-mobile
//
//  Created by Claude on 8/24/25.
//

import SwiftUI

struct RegistrationView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSecurePassword = true
    @State private var isSecureConfirmPassword = true
    @State private var authError: String? = nil
    @State private var isRegistering = false
    @State private var showSuccessAnimation = false
    
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let onRegistrationComplete: () -> Void
    @State private var authClient = AuthClient()
    
    enum Field {
        case firstName, lastName, email, password, confirmPassword
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Join thousands tracking their expenses")
                                .font(.subheadline)
                                .foregroundColor(adaptiveSecondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 16) {
                            // Name fields row
                            HStack(spacing: 12) {
                                // First name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("First Name")
                                        .font(.caption)
                                        .foregroundColor(adaptiveSecondaryText)
                                    
                                    HStack {
                                        Image(systemName: "person")
                                            .foregroundColor(adaptiveSecondaryText)
                                            .frame(width: 16)
                                        
                                        TextField("First", text: $firstName)
                                            .focused($focusedField, equals: .firstName)
                                            .textContentType(.givenName)
                                            .autocapitalization(.words)
                                    }
                                    .padding()
                                    .background(adaptiveCardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .firstName ? Color.blue : adaptiveBorderColor,
                                                lineWidth: focusedField == .firstName ? 2 : 1
                                            )
                                    )
                                    .cornerRadius(12)
                                }
                                
                                // Last name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Last Name")
                                        .font(.caption)
                                        .foregroundColor(adaptiveSecondaryText)
                                    
                                    HStack {
                                        Image(systemName: "person")
                                            .foregroundColor(adaptiveSecondaryText)
                                            .frame(width: 16)
                                        
                                        TextField("Last", text: $lastName)
                                            .focused($focusedField, equals: .lastName)
                                            .textContentType(.familyName)
                                            .autocapitalization(.words)
                                    }
                                    .padding()
                                    .background(adaptiveCardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .lastName ? Color.blue : adaptiveBorderColor,
                                                lineWidth: focusedField == .lastName ? 2 : 1
                                            )
                                    )
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Email field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email Address")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryText)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(adaptiveSecondaryText)
                                        .frame(width: 16)
                                    
                                    TextField("your.email@example.com", text: $email)
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
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryText)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(adaptiveSecondaryText)
                                        .frame(width: 16)
                                    
                                    if isSecurePassword {
                                        SecureField("At least 6 characters", text: $password)
                                            .focused($focusedField, equals: .password)
                                            .textContentType(.newPassword)
                                    } else {
                                        TextField("At least 6 characters", text: $password)
                                            .focused($focusedField, equals: .password)
                                            .textContentType(.newPassword)
                                    }
                                    
                                    Button {
                                        isSecurePassword.toggle()
                                        print("👁️ Password visibility toggled: \(isSecurePassword ? "hidden" : "visible")")
                                    } label: {
                                        Image(systemName: isSecurePassword ? "eye.slash" : "eye")
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
                                
                                // Password strength indicator
                                if !password.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(0..<4) { index in
                                            Rectangle()
                                                .frame(height: 4)
                                                .foregroundColor(passwordStrengthColor(index: index))
                                                .cornerRadius(2)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(passwordStrengthText())
                                            .font(.caption)
                                            .foregroundColor(passwordStrengthTextColor())
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            
                            // Confirm password field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryText)
                                
                                HStack {
                                    Image(systemName: "lock.shield")
                                        .foregroundColor(adaptiveSecondaryText)
                                        .frame(width: 16)
                                    
                                    if isSecureConfirmPassword {
                                        SecureField("Confirm your password", text: $confirmPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .textContentType(.newPassword)
                                    } else {
                                        TextField("Confirm your password", text: $confirmPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .textContentType(.newPassword)
                                    }
                                    
                                    Button {
                                        isSecureConfirmPassword.toggle()
                                        print("👁️ Confirm password visibility toggled: \(isSecureConfirmPassword ? "hidden" : "visible")")
                                    } label: {
                                        Image(systemName: isSecureConfirmPassword ? "eye.slash" : "eye")
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
                                            focusedField == .confirmPassword ? Color.blue : adaptiveBorderColor,
                                            lineWidth: focusedField == .confirmPassword ? 2 : 1
                                        )
                                )
                                .cornerRadius(12)
                                
                                // Password match indicator
                                if !confirmPassword.isEmpty && !password.isEmpty {
                                    let matches = passwordsMatch()
                                    HStack(spacing: 4) {
                                        Image(systemName: matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(matches ? .green : .red)
                                        
                                        Text(matches ? "Passwords match" : "Passwords don't match")
                                            .font(.caption)
                                            .foregroundColor(matches ? .green : .red)
                                    }
                                    .padding(.horizontal, 4)
                                    .animation(.easeInOut(duration: 0.2), value: matches)
                                }
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
                            
                            // Register button
                            Button {
                                print("🔘 RegistrationView: Create Account button tapped!")
                                print("✅ Can register: \(canRegister())")
                                print("⏳ Is registering: \(isRegistering)")
                                registerUser()
                            } label: {
                                HStack {
                                    if isRegistering {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                        Text("Creating Account...")
                                            .font(.system(size: 16, weight: .semibold))
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 16, weight: .semibold))
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
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
                            .disabled(!canRegister() || isRegistering)
                            .opacity((!canRegister() || isRegistering) ? 0.6 : 1.0)
                            
                            // Already have account
                            Button {
                                dismiss()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Already have an account?")
                                        .foregroundColor(adaptiveSecondaryText)
                                    Text("Sign In")
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        // Terms and privacy
                        Text("By creating an account, you agree to our [Terms of Service](https://example.com/terms) and [Privacy Policy](https://example.com/privacy).")
                            .font(.caption)
                            .foregroundColor(adaptiveSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Helper Functions
    
    private func canRegister() -> Bool {
        let firstNameOk = !firstName.isEmpty
        let lastNameOk = !lastName.isEmpty
        let emailOk = !email.isEmpty
        let passwordOk = !password.isEmpty
        let confirmPasswordOk = !confirmPassword.isEmpty
        let passwordLengthOk = password.count >= 6
        let passwordMatchOk = passwordsMatch()
        let emailValidOk = isValidEmail(email)
        
        let canReg = firstNameOk && lastNameOk && emailOk && passwordOk && confirmPasswordOk && passwordLengthOk && passwordMatchOk && emailValidOk
        
        if !canReg {
            print("🚫 canRegister validation:")
            print("   firstName: \(firstNameOk) (\(firstName))")
            print("   lastName: \(lastNameOk) (\(lastName))")
            print("   email: \(emailOk) (\(email))")
            print("   password: \(passwordOk) (length: \(password.count))")
            print("   confirmPassword: \(confirmPasswordOk) (length: \(confirmPassword.count))")
            print("   passwordLength >= 6: \(passwordLengthOk)")
            print("   passwordsMatch: \(passwordMatchOk)")
            print("   emailValid: \(emailValidOk)")
        }
        
        return canReg
    }
    
    private func passwordsMatch() -> Bool {
        let matches = password == confirmPassword && !password.isEmpty && !confirmPassword.isEmpty
        if !password.isEmpty && !confirmPassword.isEmpty {
            print("🔒 Password match check: '\(password)' == '\(confirmPassword)' -> \(matches)")
        }
        return matches
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func passwordStrength() -> Int {
        var strength = 0
        if password.count >= 6 { strength += 1 }
        if password.count >= 8 { strength += 1 }
        if password.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil { strength += 1 }
        if password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil { strength += 1 }
        return strength
    }
    
    private func passwordStrengthColor(index: Int) -> Color {
        let strength = passwordStrength()
        if index < strength {
            switch strength {
            case 1: return .red
            case 2: return .orange
            case 3: return .yellow
            case 4: return .green
            default: return .gray
            }
        }
        return .gray.opacity(0.3)
    }
    
    private func passwordStrengthText() -> String {
        switch passwordStrength() {
        case 0...1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        default: return "Weak"
        }
    }
    
    private func passwordStrengthTextColor() -> Color {
        switch passwordStrength() {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .red
        }
    }
    
    private func registerUser() {
        print("🚀 RegistrationView: Starting registration process...")
        print("📧 Email: '\(email)'")
        print("🔒 Password length: \(password.count)")
        print("👤 First name: '\(firstName)'")
        print("👤 Last name: '\(lastName)'")
        print("✅ Can register: \(canRegister())")
        
        guard canRegister() else {
            print("❌ RegistrationView: Registration validation failed")
            authError = "Please fill in all fields correctly."
            return
        }
        
        print("🔄 RegistrationView: Setting isRegistering to true")
        isRegistering = true
        authError = nil
        
        let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
        print("📝 Full name: '\(fullName)'")
        
        Task {
            do {
                print("📤 RegistrationView: Calling authClient.registerWithEmail...")
                let response = try await authClient.registerWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: fullName
                )
                
                await MainActor.run {
                    print("✅ RegistrationView: Registration successful!")
                    print("🎫 Token received: \(response.token.prefix(20))...")
                    saveToken(response.token)
                    saveRefreshToken(response.refresh_token)
                    isRegistering = false
                    showSuccessAnimation = true
                    
                    // Dismiss after a brief success animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("🎊 RegistrationView: Calling onRegistrationComplete")
                        onRegistrationComplete()
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ RegistrationView: Registration failed with error: \(error)")
                    print("🐛 Error details: \(String(describing: error))")
                    isRegistering = false
                    
                    if let authError = error as? AuthError {
                        self.authError = authError.localizedDescription
                        print("📋 AuthError message: \(authError.localizedDescription)")
                    } else {
                        self.authError = "Registration failed: \(error.localizedDescription)"
                        print("📋 Generic error message: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview {
    RegistrationView {
        print("Registration completed")
    }
}
