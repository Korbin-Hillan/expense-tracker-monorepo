//
//  LandingView.swift
//  expense-tracker-mobile
//
//  Created by Korbin Hillan on 8/19/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import UIKit

extension UIApplication {
    static var topViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

private final class AppleAuthCoordinator: NSObject,
                                         ASAuthorizationControllerDelegate,
                                         ASAuthorizationControllerPresentationContextProviding {

    var onSuccess: ((ASAuthorization) -> Void)?
    var onError: ((Error) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess?(authorization)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        onError?(error)
    }
}

struct LandingView: View {
    @State private var showingAuthSheet = false
    @State private var animateTitle = false
    @State private var animateLogo = false
    @State private var animateButton = false
    @Environment(\.colorScheme) var colorScheme
    var onAuthenticated: () -> Void
    @State private var appleCoordinator = AppleAuthCoordinator()
    @State private var authClient = AuthClient()
    @State private var authError: String? = nil
    @State private var isAuthenticating = false
    
    // Adaptive colors for dark mode
    private var adaptiveGradientColors: [Color] {
        colorScheme == .dark ? [
            Color(hex: "#1a1a2e"),
            Color(hex: "#16213e"),
            Color(hex: "#0f3460"),
            Color(hex: "#533483")
        ] : [
            Color(hex: "#667eea"),
            Color(hex: "#764ba2"),
            Color(hex: "#f093fb"),
            Color(hex: "#f5576c")
        ]
    }
    
    private var adaptiveButtonBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.white
    }
    
    private var adaptiveButtonForeground: Color {
        colorScheme == .dark ? Color.black : Color.black
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced gradient background with animation
                AnimatedGradientBackground(colors: adaptiveGradientColors)
                    .ignoresSafeArea()
                
                // Floating particles background effect
                FloatingParticles()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top section with title
                    VStack(spacing: 24) {
                        // App title with animation
                        VStack(spacing: 12) {
                            Text("Expense")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .scaleEffect(animateTitle ? 1.0 : 0.8)
                                .opacity(animateTitle ? 1.0 : 0)
                            
                            Text("Tracker")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .scaleEffect(animateTitle ? 1.0 : 0.8)
                                .opacity(animateTitle ? 1.0 : 0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateTitle)
                        }
                        
                        // Subtitle
                        Text("Take control of your financial future")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .opacity(animateTitle ? 1.0 : 0)
                            .offset(y: animateTitle ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.6), value: animateTitle)
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 60)
                    
                    Spacer()
                    
                    // Logo section
                    VStack(spacing: 24) {
                        // Enhanced logo with glow effect
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 50,
                                        endRadius: 150
                                    )
                                )
                                .frame(width: 300, height: 300)
                                .blur(radius: 20)
                                .opacity(animateLogo ? 0.8 : 0)
                            
                            // Logo container
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .background(Material.ultraThinMaterial)
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 2)
                                    )
                                
                                // You can replace this with your actual logo image
                                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                            .scaleEffect(animateLogo ? 1.0 : 0.3)
                            .opacity(animateLogo ? 1.0 : 0)
                            .rotationEffect(.degrees(animateLogo ? 0 : 180))
                        }
                        
                        // Features preview
                        FeatureHighlights()
                            .opacity(animateLogo ? 1.0 : 0)
                            .offset(y: animateLogo ? 0 : 30)
                            .animation(.easeOut(duration: 0.8).delay(1.2), value: animateLogo)
                    }
                    
                    Spacer()
                    
                    // Bottom section with CTA
                    VStack(spacing: 16) {
                        // Main CTA button
                        Button {
                            print("🔘 LandingView: Get Started button pressed, showing auth sheet")
                            showingAuthSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("Get Started")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                ZStack {
                                    // Background glow
                                    RoundedRectangle(cornerRadius: 30)
                                        .fill(adaptiveButtonBackground.opacity(0.2))
                                        .blur(radius: 10)
                                    
                                    // Main background
                                    RoundedRectangle(cornerRadius: 30)
                                        .fill(adaptiveButtonBackground)
                                }
                            )
                            .foregroundColor(adaptiveButtonForeground)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .scaleEffect(animateButton ? 1.0 : 0.8)
                            .opacity(animateButton ? 1.0 : 0)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 32)
                        
                        // Secondary text
                        Text("Join thousands of users taking control of their finances")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .opacity(animateButton ? 1.0 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.8), value: animateButton)
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
                }
            }
        }
        .onAppear {
            // Staggered animations
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateTitle = true
            }
            
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.8)) {
                animateLogo = true
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4)) {
                animateButton = true
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthOptionsSheet(
                onApple: startAppleSignIn,
                onGoogle: startGoogleSignIn,
                onEmail: startEmailSignIn,
                onAuthenticated: {
                    showingAuthSheet = false
                    onAuthenticated()
                },
                authError: authError,
                isAuthenticating: isAuthenticating
            )
            .presentationDragIndicator(.hidden)
            .presentationDetents([.fraction(0.85), .large])
        }
        .onChange(of: showingAuthSheet) { isShowing in
            print("📱 LandingView: Auth sheet state changed to: \(isShowing)")
        }
    }
    
    private func startEmailSignIn(email: String, password: String) {
        print("🔘 LandingView: startEmailSignIn called with email: '\(email)' password length: \(password.count)")
        
        guard !email.isEmpty, !password.isEmpty else {
            print("❌ LandingView: Empty email or password")
            authError = "Please enter both email and password."
            return
        }
        
        print("🔄 LandingView: Starting authentication process...")
        isAuthenticating = true
        authError = nil
        
        Task {
            print("⚡ LandingView: Task started for authentication")
            
            // Test connection first
            await authClient.testConnection()
            
            do {
                let response = try await authClient.loginOrRegister(email: email, password: password)
                await MainActor.run {
                    print("✅ LandingView: Email auth successful. JWT:", response.token.prefix(16), "…")
                    isAuthenticating = false
                    showingAuthSheet = false
                    onAuthenticated()
                }
            } catch {
                await MainActor.run {
                    print("❌ LandingView: Authentication failed with error: \(error)")
                    isAuthenticating = false
                    if let authError = error as? AuthError {
                        self.authError = authError.localizedDescription
                        print("❌ LandingView: AuthError: \(authError.localizedDescription)")
                    } else {
                        self.authError = "Authentication failed: \(error.localizedDescription)"
                        print("❌ LandingView: Generic error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func startGoogleSignIn() {
        guard let presenter = UIApplication.topViewController else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error = error {
                print("Sign-in error:", error.localizedDescription)
                return
            }
            guard let idToken = result?.user.idToken?.tokenString else {
                print("No Google ID token")
                return
            }

            Task {
                do {
                    let resp = try await auth(idToken)
                    print("✅ app JWT:", resp.token.prefix(16), "…")
                    showingAuthSheet = false
                    onAuthenticated()
                } catch {
                    print("❌ auth error:", error.localizedDescription)
                }
            }
        }
    }
    
    private func startAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = appleCoordinator
        controller.presentationContextProvider = appleCoordinator

        appleCoordinator.onSuccess = { authorization in
            if let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
               let tokenData = cred.identityToken,
               let token = String(data: tokenData, encoding: .utf8) {
                Task {
                    do {
                        let _ = try await auth(token)
                        showingAuthSheet = false
                        onAuthenticated()
                    } catch {
                        print("Auth failed:", error.localizedDescription)
                    }
                }
            } else {
                print("No identityToken from Apple")
            }
        }
        
        appleCoordinator.onError = { error in
            print("Could not authenticate: \(error.localizedDescription)")
        }

        controller.performRequests()
    }
}

// Animated gradient background
struct AnimatedGradientBackground: View {
    let colors: [Color]
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// Floating particles effect
struct FloatingParticles: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var scale: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(.white.opacity(particle.opacity))
                    .frame(width: 4, height: 4)
                    .scaleEffect(particle.scale)
                    .position(x: particle.x, y: particle.y)
                    .animation(
                        .linear(duration: Double.random(in: 10...20))
                        .repeatForever(autoreverses: false),
                        value: particles.count
                    )
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<20).map { _ in
            Particle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                opacity: Double.random(in: 0.1...0.3),
                scale: CGFloat.random(in: 0.5...1.5)
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            for i in particles.indices {
                particles[i].y -= 0.5
                particles[i].x += CGFloat.random(in: -0.5...0.5)
                
                if particles[i].y < -10 {
                    particles[i].y = UIScreen.main.bounds.height + 10
                    particles[i].x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                }
            }
        }
    }
}

// Feature highlights
struct FeatureHighlights: View {
    @Environment(\.colorScheme) var colorScheme
    let features = [
        ("chart.bar.fill", "Track Expenses"),
        ("target", "Set Budgets"),
        ("bell.fill", "Bill Reminders")
    ]
    
    private var adaptiveFeatureBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.15)
    }
    
    private var adaptiveFeatureBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.2)
    }
    
    var body: some View {
        HStack(spacing: 32) {
            ForEach(features, id: \.0) { icon, title in
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 48, height: 48)
                        .background(adaptiveFeatureBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(adaptiveFeatureBorder, lineWidth: 1)
                        )
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

// Custom button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    LandingView(onAuthenticated: {})
}
