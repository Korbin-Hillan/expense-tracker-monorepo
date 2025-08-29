//
//  AccountSettingsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI
import LocalAuthentication
import UserNotifications

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    var onSignOut: () -> Void = {}
    
    @State private var notificationsEnabled = UserSettings.shared.notificationsEnabled
    @State private var biometricEnabled = UserSettings.shared.biometricEnabled
    @State private var selectedDarkMode = UserSettings.shared.darkModePreference
    @State private var showingDarkModeOptions = false
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    
    private let darkModeOptions = ["Light", "Dark", "System"]
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Preferences
                Section("Preferences") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Notifications")
                        Spacer()
                        Toggle("", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { _, value in
                                updateNotificationSettings(value)
                            }
                    }
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                        Text("Face ID / Touch ID")
                        Spacer()
                        Toggle("", isOn: $biometricEnabled)
                            .onChange(of: biometricEnabled) { _, value in
                                updateBiometricSettings(value)
                            }
                    }
                    
                    Button(action: { showingDarkModeOptions = true }) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.purple)
                            Text("Dark Mode")
                            Spacer()
                            Text(selectedDarkMode)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // MARK: - Data & Privacy
                Section("Data & Privacy") {
                    Button(action: { showingExportSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.green)
                            Text("Export Data")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }
                
                // MARK: - Support
                Section("Support") {
                    Button(action: { openHelpSupport() }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Help & Support")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showAbout() }) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.gray)
                            Text("About")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Dark Mode", isPresented: $showingDarkModeOptions) {
                ForEach(darkModeOptions, id: \.self) { option in
                    Button(option) {
                        selectedDarkMode = option
                        applyDarkModeChange(option)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportDataSheet()
            }
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Continue", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all data. This action cannot be undone.")
            }
            .sheet(isPresented: $showingDeleteConfirmation) {
                DeleteAccountConfirmationView(
                    confirmationText: $deleteConfirmationText,
                    isDeleting: $isDeletingAccount,
                    onDelete: {
                        deleteAccount()
                    },
                    onCancel: {
                        showingDeleteConfirmation = false
                        deleteConfirmationText = ""
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    private func updateNotificationSettings(_ enabled: Bool) {
        UserSettings.shared.notificationsEnabled = enabled
        
        if enabled {
            requestNotificationPermissions()
        } else {
            // Disable notifications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func updateBiometricSettings(_ enabled: Bool) {
        if enabled {
            authenticateWithBiometrics { success in
                if success {
                    UserSettings.shared.biometricEnabled = true
                } else {
                    DispatchQueue.main.async {
                        self.biometricEnabled = false
                    }
                }
            }
        } else {
            UserSettings.shared.biometricEnabled = false
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.notificationsEnabled = false
                    UserSettings.shared.notificationsEnabled = false
                }
            }
        }
    }
    
    private func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                   localizedReason: "Enable biometric authentication for secure access") { success, authError in
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        Task {
            do {
                // Make API call to delete account on server
                let userAPI = UserAPI()
                let response = try await userAPI.deleteAccount()
                
                Logger.shared.info("Account deletion successful: \(response.message)")
                Logger.shared.info("Deleted data summary: transactions=\(response.deletedData.transactions), expenses=\(response.deletedData.expenses)")
                
                // Clear all local data after successful server deletion
                await MainActor.run {
                    clearLocalData()
                    isDeletingAccount = false
                    showingDeleteConfirmation = false
                    signOutUser()
                }
                
            } catch {
                Logger.shared.error("Failed to delete account: \(error)")
                
                await MainActor.run {
                    isDeletingAccount = false
                    // Show error to user
                    print("Failed to delete account: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearLocalData() {
        // Clear UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "notificationsEnabled")
        userDefaults.removeObject(forKey: "biometricEnabled")
        userDefaults.removeObject(forKey: "darkModePreference")
        
        // Clear any cached tokens or user data
        clearTokens()
    }
    
    
    private func signOutUser() {
        // This should trigger the app to return to login screen
        clearTokens()
        
        // Close the settings sheet first, then trigger sign out
        dismiss()
        
        // Call the onSignOut callback to navigate to login
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onSignOut()
        }
    }
    
    private func openHelpSupport() {
        if let url = URL(string: "https://support.yourapp.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func showAbout() {
        print("ℹ️ Showing about information...")
        // TODO: Show app version info sheet
    }
    
    private func applyDarkModeChange(_ mode: String) {
        selectedDarkMode = mode
        UserSettings.shared.darkModePreference = mode
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    switch mode {
                    case "Light":
                        window.overrideUserInterfaceStyle = .light
                    case "Dark":
                        window.overrideUserInterfaceStyle = .dark
                    default:
                        window.overrideUserInterfaceStyle = .unspecified
                    }
                }
            }
        }
    }
}
