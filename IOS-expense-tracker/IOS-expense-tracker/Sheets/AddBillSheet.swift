//
//  AddBillSheet.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct AddBillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var frequency: BillFrequency = .monthly
    @State private var category: String = "Utilities"
    @State private var nextDue: Date = Date()
    @State private var selectedColor: Color = .blue
    
    let onSave: (RecurringBill) -> Void
    
    private let categories = ["Utilities", "Rent", "Entertainment", "Insurance", "Subscriptions", "Loans", "Other"]
    private let colors: [Color] = [.blue, .green, .red, .orange, .purple, .pink, .yellow, .cyan]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Bill name", text: $name)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    DatePicker("Next due date", selection: $nextDue, displayedComponents: .date)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            Button(action: { 
                                selectedColor = color
                                print("Selected color: \(colorToString(color))")
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(.primary, lineWidth: colorsMatch(selectedColor, color) ? 3 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Bill")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBill()
                    }
                    .disabled(name.isEmpty || amount.isEmpty || Double(amount) == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveBill() {
        guard let billAmount = Double(amount) else { return }
        
        let newBill = RecurringBill(
            name: name,
            amount: billAmount,
            frequency: frequency,
            category: category,
            nextDue: nextDue,
            isActive: true,
            color: selectedColor
        )
        
        onSave(newBill)
        dismiss()
    }
    
    private func colorsMatch(_ color1: Color, _ color2: Color) -> Bool {
        return colorToString(color1) == colorToString(color2)
    }
    
    private func colorToString(_ color: Color) -> String {
        switch color {
        case .blue: return "blue"
        case .green: return "green"
        case .red: return "red"
        case .orange: return "orange"
        case .purple: return "purple"
        case .pink: return "pink"
        case .yellow: return "yellow"
        case .cyan: return "cyan"
        default: return "blue"
        }
    }
}
