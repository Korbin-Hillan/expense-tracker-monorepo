//
//  AppConfig.swift
//  IOS-expense-tracker
//
//  Configuration settings for the app
//

import Foundation

struct AppConfig {
    
    // MARK: - API Configuration
    
    #if DEBUG
    static let baseURL = URL(string: "http://192.168.0.119:3000")!
    #else
    static let baseURL = URL(string: "https://your-production-api.com")!
    #endif
    
    // MARK: - Budget Configuration
    
    struct Budget {
        static let warningThreshold: Double = 0.6    // 60%
        static let alertThreshold: Double = 0.8      // 80%
        static let dangerThreshold: Double = 1.0     // 100%
        static let defaultBudget: Double = 2500.00
    }
    
    // MARK: - UI Configuration
    
    struct UI {
        static let cornerRadius: CGFloat = 16
        static let cardCornerRadius: CGFloat = 20
        static let smallCornerRadius: CGFloat = 12
        
        static let standardPadding: CGFloat = 16
        static let largePadding: CGFloat = 24
        static let smallPadding: CGFloat = 8
        
        static let animationDuration: Double = 0.3
        static let quickAnimationDuration: Double = 0.1
    }
    
    // MARK: - API Limits
    
    struct API {
        static let defaultPageSize = 20
        static let maxPageSize = 100
        static let maxBulkLoadSize = 1000
    }
}