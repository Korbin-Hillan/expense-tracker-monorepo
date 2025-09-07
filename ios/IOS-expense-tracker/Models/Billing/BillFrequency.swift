//
//  BillFrequency.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import Foundation

enum BillFrequency: String, CaseIterable, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}
