//
//  SetBudgetView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI
struct SetBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var currentBudget: Double
    @State private var newBudget: String = ""
    @State private var selectedCategory: BudgetCategory = .monthly
    
    enum BudgetCategory: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
        
        var multiplier: Double {
            switch self {
            case .weekly: return 1.0
            case .monthly: return 4.33 // Average weeks per month
            case .quarterly: return 13.0
            case .yearly: return 52.0
            }
        }
    }
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Current Budget Display
                    VStack(spacing: 16) {
                        Text("Current Budget")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        Text("$\(currentBudget, specifier: "%.2f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        
                        Text("per month")
                            .font(.subheadline)
                            .foregroundColor(adaptiveSecondaryTextColor)
                    }
                    .padding(24)
                    .background(adaptiveCardBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Budget Category Selector
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Budget Period")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(BudgetCategory.allCases, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    VStack(spacing: 8) {
                                        Text(category.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(selectedCategory == category ? .white : adaptiveTextColor)
                                        
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(height: 60)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedCategory == category ? .blue : adaptiveCardBackground)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                            }
                        }
                    }
                    
                    // Budget Input
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Set New \(selectedCategory.rawValue) Budget")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(adaptiveTextColor)
                                
                                TextField("0.00", text: $newBudget)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(adaptiveTextColor)
                            }
                            .padding(16)
                            .background(adaptiveCardBackground)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            
                            if !newBudget.isEmpty, let amount = Double(newBudget) {
                                let monthlyEquivalent = amount / selectedCategory.multiplier * BudgetCategory.monthly.multiplier
                                Text("≈ $\(monthlyEquivalent, specifier: "%.2f") per month")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryTextColor)
                            }
                        }
                    }
                    
                    // Quick preset buttons
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Presets")
                            .font(.headline)
                            .foregroundColor(adaptiveTextColor)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(budgetPresets, id: \.self) { preset in
                                Button(action: { newBudget = String(format: "%.0f", preset) }) {
                                    Text("$\(preset, specifier: "%.0f")")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .frame(height: 40)
                                        .frame(maxWidth: .infinity)
                                        .background(adaptiveCardBackground)
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(newBudget.isEmpty || Double(newBudget) == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            newBudget = String(format: "%.0f", currentBudget)
        }
    }
    
    private var budgetPresets: [Double] {
        switch selectedCategory {
        case .weekly: return [100, 200, 300, 500, 750, 1000]
        case .monthly: return [500, 1000, 1500, 2000, 2500, 3000]
        case .quarterly: return [1500, 3000, 4500, 6000, 7500, 9000]
        case .yearly: return [6000, 12000, 18000, 24000, 30000, 36000]
        }
    }
    
    private func saveBudget() {
        guard let amount = Double(newBudget) else { return }
        
        // Convert to monthly equivalent
        let monthlyBudget = amount / selectedCategory.multiplier * BudgetCategory.monthly.multiplier
        currentBudget = monthlyBudget
        
        // Here you would typically save to UserDefaults or a database
        UserDefaults.standard.set(monthlyBudget, forKey: "monthlyBudget")
        
        dismiss()
    }
}
