//
//  EditTransactionSheet.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let transaction: TransactionDTO
    let onSave: (TransactionDTO) -> Void
    
    @State private var note: String
    @State private var amount: String
    @State private var category: String
    @State private var type: String
    
    private let categories = ["Food", "Transport", "Entertainment", "Shopping", "Bills", "Healthcare", "Education", "Travel", "Other"]
    
    init(transaction: TransactionDTO, onSave: @escaping (TransactionDTO) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        
        _note = State(initialValue: transaction.note ?? "")
        _amount = State(initialValue: String(transaction.amount))
        _category = State(initialValue: transaction.category)
        _type = State(initialValue: transaction.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Transaction Details") {
                    Picker("Type", selection: $type) {
                        Text("Income").tag("income")
                        Text("Expense").tag("expense")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Note (optional)", text: $note)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section("Transaction Info") {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text("Recently") // This would show actual creation date in real app
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ID")
                        Spacer()
                        Text(String(transaction.id.prefix(8)) + "...")
                            .foregroundColor(.secondary)
                            .font(.monospaced(.body)())
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let transactionAmount = Double(amount) else { return }
        
        // Create updated transaction (in real app, this would have proper ID handling)
        let updatedTransaction = TransactionDTO(
            id: transaction.id,
            type: type,
            amount: transactionAmount,
            category: category,
            note: note.isEmpty ? nil : note,
            date: transaction.date
        )
        
        onSave(updatedTransaction)
        dismiss()
    }
}
