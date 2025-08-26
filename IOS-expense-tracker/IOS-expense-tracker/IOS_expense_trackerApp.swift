//
//  IOS_expense_trackerApp.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
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
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task { _ = try? await AuthSession.shared.validAccessToken() }
                    }
                }
                .task {
                    if #available(iOS 17, *) {
                        try? await ExpenseAppShortcutsProvider.updateAppShortcutParameters()
                    }
                }
        }
    }
}
