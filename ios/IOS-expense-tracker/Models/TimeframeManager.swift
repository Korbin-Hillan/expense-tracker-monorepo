//
//  TimeframeManager.swift
//  IOS-expense-tracker
//
//  Created by Claude on 8/28/25.
//

import Foundation

enum TimeFrame: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
}

@MainActor
class TimeframeManager: ObservableObject {
    @Published var selectedTimeframe: TimeFrame = .month
    
    static let shared = TimeframeManager()
    
    private init() {}
    
    func setTimeframe(_ timeframe: TimeFrame) {
        selectedTimeframe = timeframe
    }
    
    func filterTransactionsByTimeframe(_ allTransactions: [TransactionDTO]) -> [TransactionDTO] {
        let calendar = Calendar.current
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        
        return allTransactions.filter { transaction in
            guard let date = dateFormatter.date(from: transaction.date) else { return false }
            
            switch selectedTimeframe {
            case .week:
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                return date >= threeMonthsAgo
            case .year:
                return calendar.isDate(date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    func dayCountForTimeframe() -> Int {
        switch selectedTimeframe {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        }
    }
}