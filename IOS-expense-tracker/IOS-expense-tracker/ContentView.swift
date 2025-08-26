//
//  ContentView.swift
//  expense-tracker-backend
//
//  Created by Korbin Hillan on 8/23/25.
//

import SwiftUI

private enum AuthScreen {
    case signIn
    case home
}



struct ContentView: View {
    @State private var screen: AuthScreen = .signIn

    var body: some View {
        Group {
            switch screen {
            case .signIn:
                LandingView(onAuthenticated: { screen = .home })
            case .home:
                AppView(onSignOut: handleSignOut)
            }
        }
        .task {
            checkExistingAuth()
        }
    }
    
    private func handleSignOut() {
        BillStorage.shared.clearUserBills()
        clearTokens()
        screen = .signIn
    }
    
    private func checkExistingAuth() {
        Task {
            do {
                // Try to get a valid access token (this will refresh if needed)
                let _ = try await AuthSession.shared.validAccessToken()
                await MainActor.run {
                    print("✅ ContentView: Valid token found, showing home")
                    BillStorage.shared.refreshForNewUser()
                    screen = .home
                }
            } catch {
                await MainActor.run {
                    print("❌ ContentView: No valid token, showing sign in. Error: \(error)")
                    // Clear any invalid tokens
                    clearTokens()
                    screen = .signIn
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
