//
//  AccountSettingsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var notificationsEnabled = true
    @State private var biometricEnabled = false
    @State private var selectedDarkMode = "System"
    @State private var showingDarkModeOptions = false
    
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
                    }
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                        Text("Face ID / Touch ID")
                        Spacer()
                        Toggle("", isOn: $biometricEnabled)
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
                    Button(action: { exportData() }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.green)
                            Text("Export Data")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showDeleteAccountAlert() }) {
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
        }
    }
    
    // MARK: - Actions
    private func exportData() {
        print("📤 Exporting user data...")
        // TODO: Implement data export functionality
    }
    
    private func showDeleteAccountAlert() {
        print("🗑️ Show delete account alert...")
        // TODO: Implement delete account confirmation
    }
    
    private func openHelpSupport() {
        print("❓ Opening help & support...")
        // TODO: Open help documentation or support contact
    }
    
    private func showAbout() {
        print("ℹ️ Showing about information...")
        // TODO: Show app version, privacy policy, terms of service
    }
    
    private func applyDarkModeChange(_ mode: String) {
        print("🌙 Applying dark mode change: \(mode)")
        // TODO: Apply dark mode preference
        // This would typically involve UserDefaults storage and app-wide theme changes
    }
}
