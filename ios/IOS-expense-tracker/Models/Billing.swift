//
//  Billing.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct RecurringBill: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Double
    let frequency: BillFrequency
    let category: String
    let nextDue: Date?
    let isActive: Bool
    let colorName: String

    var color: Color {
        switch colorName {
        case "blue": .blue; case "green": .green; case "red": .red; case "orange": .orange
        case "purple": .purple; case "pink": .pink; case "yellow": .yellow; case "cyan": .cyan
        default: .blue
        }
    }
    
    // Codable initializer for decoding from UserDefaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.frequency = try container.decode(BillFrequency.self, forKey: .frequency)
        self.category = try container.decode(String.self, forKey: .category)
        self.nextDue = try container.decodeIfPresent(Date.self, forKey: .nextDue)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.colorName = try container.decode(String.self, forKey: .colorName)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, amount, frequency, category, nextDue, isActive, colorName
    }

    init(name: String, amount: Double, frequency: BillFrequency, category: String, nextDue: Date?, isActive: Bool, color: Color) {
        self.id = UUID()
        self.name = name; self.amount = amount; self.frequency = frequency
        self.category = category; self.nextDue = nextDue; self.isActive = isActive
        switch color {
        case .blue: self.colorName = "blue"
        case .green: self.colorName = "green"
        case .red: self.colorName = "red"
        case .orange: self.colorName = "orange"
        case .purple: self.colorName = "purple"
        case .pink: self.colorName = "pink"
        case .yellow: self.colorName = "yellow"
        case .cyan: self.colorName = "cyan"
        default: self.colorName = "blue"
        }
    }
    
    // Create a new bill with updated properties but same ID
    init(id: UUID, name: String, amount: Double, frequency: BillFrequency, category: String, nextDue: Date?, isActive: Bool, color: Color) {
        self.id = id
        self.name = name; self.amount = amount; self.frequency = frequency
        self.category = category; self.nextDue = nextDue; self.isActive = isActive
        switch color {
        case .blue: self.colorName = "blue"
        case .green: self.colorName = "green"
        case .red: self.colorName = "red"
        case .orange: self.colorName = "orange"
        case .purple: self.colorName = "purple"
        case .pink: self.colorName = "pink"
        case .yellow: self.colorName = "yellow"
        case .cyan: self.colorName = "cyan"
        default: self.colorName = "blue"
        }
    }
}
