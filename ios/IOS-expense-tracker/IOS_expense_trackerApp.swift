//
//  IOS_expense_trackerApp.swift
//  IOS-expense-tracker
//

import SwiftUI
import GoogleSignIn
import AppIntents

@main
struct expense_tracker_mobileApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                // iOS 17+ onChange signature
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { _ = try? await AuthSession.shared.validAccessToken() }
                    }
                }
                .task {
                    if #available(iOS 17, *) {
                        // This function is not async/throwing, so just call it.
                        ExpenseAppShortcutsProvider.updateAppShortcutParameters()
                    }
                }
        }
    }
}
