//
//  UserSettings.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/28/25.
//

import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let biometricEnabled = "biometricEnabled"
        static let darkModePreference = "darkModePreference"
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            userDefaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        }
    }
    
    @Published var biometricEnabled: Bool {
        didSet {
            userDefaults.set(biometricEnabled, forKey: Keys.biometricEnabled)
        }
    }
    
    @Published var darkModePreference: String {
        didSet {
            userDefaults.set(darkModePreference, forKey: Keys.darkModePreference)
        }
    }
    
    private init() {
        self.notificationsEnabled = userDefaults.bool(forKey: Keys.notificationsEnabled)
        self.biometricEnabled = userDefaults.bool(forKey: Keys.biometricEnabled)
        self.darkModePreference = userDefaults.string(forKey: Keys.darkModePreference) ?? "System"
    }
}