//
//  BillsView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

enum BillSortOption { case amount, dueDate, name }

struct BillsView: View {
    @StateObject private var billStorage = BillStorage.shared
    @State private var showingAddBill = false
    @State private var showingEditBill = false
    @State private var selectedBill: RecurringBill?
    @Environment(\.colorScheme) var colorScheme
    
    private var bills: [RecurringBill] {
        billStorage.bills
    }
    
    // Use adaptive system colors within material cards
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Bills & Subscriptions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Track and manage your recurring payments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Monthly overview card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("$\(monthlyTotal, specifier: "%.2f")")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Next Due")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(nextDueDate)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Bills count breakdown
                    HStack(spacing: 16) {
                        BillStatChip(count: activeBillsCount, label: "Active", color: .green)
                        BillStatChip(count: dueSoonCount, label: "Due Soon", color: .orange)
                        BillStatChip(count: overdueCount, label: "Overdue", color: .red)
                    }
                }
                .padding(24)
                .cardStyle(cornerRadius: 20)
                
                // Add Bill Button
                Button(action: { showingAddBill = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Add New Bill")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Bills List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your Bills")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Menu {
                            Button("Sort by Amount") { sortBills(by: .amount) }
                            Button("Sort by Due Date") { sortBills(by: .dueDate) }
                            Button("Sort by Name") { sortBills(by: .name) }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    if bills.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No bills added yet")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Add your first recurring bill to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .cardStyle(cornerRadius: 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(bills) { bill in
                                BillCard(bill: bill, onEdit: { editBill(bill) }, onDelete: { deleteBill(bill) })
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showingAddBill) {
            AddBillSheet { newBill in
                billStorage.addBill(newBill)
            }
        }
        .sheet(isPresented: $showingEditBill) {
            if let bill = selectedBill {
                EditBillSheet(bill: bill) { updatedBill in
                    billStorage.updateBill(updatedBill)
                }
            }
        }
    }
    
    private var monthlyTotal: Double {
        bills.reduce(0) { total, bill in
            switch bill.frequency {
            case .weekly: return total + (bill.amount * 4.33)
            case .monthly: return total + bill.amount
            case .quarterly: return total + (bill.amount / 3)
            case .yearly: return total + (bill.amount / 12)
            }
        }
    }
    
    private var nextDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return bills.first?.nextDue.map { formatter.string(from: $0) } ?? "None"
    }
    
    private var activeBillsCount: Int {
        bills.filter { $0.isActive }.count
    }
    
    private var dueSoonCount: Int {
        bills.filter { bill in
            guard let nextDue = bill.nextDue else { return false }
            return nextDue <= Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }.count
    }
    
    private var overdueCount: Int {
        bills.filter { bill in
            guard let nextDue = bill.nextDue else { return false }
            return nextDue < Date()
        }.count
    }
    
    private func sortBills(by: BillSortOption) {
        switch by {
        case .amount:
            billStorage.bills.sort { $0.amount > $1.amount }
        case .dueDate:
            billStorage.bills.sort { ($0.nextDue ?? Date.distantFuture) < ($1.nextDue ?? Date.distantFuture) }
        case .name:
            billStorage.bills.sort { $0.name < $1.name }
        }
        billStorage.saveBills()
    }
    
    private func editBill(_ bill: RecurringBill) {
        print("🔧 Editing bill: \(bill.name)")
        selectedBill = bill
        showingEditBill = true
    }
    
    private func deleteBill(_ bill: RecurringBill) {
        billStorage.deleteBill(bill)
    }
}
