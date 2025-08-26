//
//  BillStorage.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import Foundation
class BillStorage: ObservableObject {
    static let shared = BillStorage()
    
    // Include user ID in storage key to separate bills per user
    private var storageKey: String {
        if let token = loadToken() {
            // Extract user ID from JWT token
            let parts = token.split(separator: ".")
            if parts.count >= 2,
               let payloadData = base64URLDecode(String(parts[1])),
               let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
               let userId = payload["sub"] as? String {
                return "saved_bills_\(userId)"
            }
        }
        return "saved_bills_default"
    }
    
    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder,
                                  withPad: "=", startingAt: 0)
        }
        
        return Data(base64Encoded: base64)
    }
    
    @Published var bills: [RecurringBill] = []
    
    private init() {
        loadBills()
    }
    
    func saveBills() {
        do {
            let data = try JSONEncoder().encode(bills)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("✅ BillStorage: Saved \(bills.count) bills to UserDefaults")
        } catch {
            print("❌ BillStorage: Failed to save bills: \(error)")
        }
    }
    
    func loadBills() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📋 BillStorage: No saved bills found, loading sample data")
            loadSampleBills()
            return
        }
        
        do {
            bills = try JSONDecoder().decode([RecurringBill].self, from: data)
            print("✅ BillStorage: Loaded \(bills.count) bills from UserDefaults")
        } catch {
            print("❌ BillStorage: Failed to decode bills: \(error), loading sample data")
            loadSampleBills()
        }
    }
    
    func addBill(_ bill: RecurringBill) {
        bills.append(bill)
        saveBills()
        print("➕ BillStorage: Added bill: \(bill.name)")
    }
    
    func updateBill(_ updatedBill: RecurringBill) {
        if let index = bills.firstIndex(where: { $0.id == updatedBill.id }) {
            bills[index] = updatedBill
            saveBills()
            print("✏️ BillStorage: Updated bill: \(updatedBill.name)")
        }
    }
    
    func deleteBill(_ bill: RecurringBill) {
        bills.removeAll { $0.id == bill.id }
        saveBills()
        print("🗑️ BillStorage: Deleted bill: \(bill.name)")
    }
    
    func clearUserBills() {
        bills.removeAll()
        saveBills()
        print("🗑️ BillStorage: Cleared all bills for user switch")
    }
    
    func refreshForNewUser() {
        loadBills()
        print("🔄 BillStorage: Refreshed bills for new user")
    }
    
    private func loadSampleBills() {
        bills = [
            RecurringBill(
                name: "Netflix",
                amount: 15.99,
                frequency: .monthly,
                category: "Entertainment",
                nextDue: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                isActive: true,
                color: .red
            ),
            RecurringBill(
                name: "Spotify",
                amount: 9.99,
                frequency: .monthly,
                category: "Entertainment",
                nextDue: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
                isActive: true,
                color: .green
            ),
            RecurringBill(
                name: "Internet",
                amount: 79.99,
                frequency: .monthly,
                category: "Utilities",
                nextDue: Calendar.current.date(byAdding: .day, value: 20, to: Date()),
                isActive: true,
                color: .blue
            )
        ]
        saveBills()
    }
}
