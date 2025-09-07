//
//  EditBudgetsSheet.swift
//  IOS-expense-tracker
//

import SwiftUI

struct EditBudgetsSheet: View {
    let initialBudgets: [BudgetItemDTO]
    let suggestedCategories: [String]
    var onSaved: ([BudgetItemDTO]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row] = []
    @State private var saving = false
    @State private var error: String?

    struct Row: Identifiable, Hashable {
        let id = UUID()
        var category: String
        var monthly: String // text field value
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Quick Presets")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([50,100,200,300,400,500,1000,1500,2000], id: \.self) { p in
                                Button("$\(p)") {
                                    rows.append(Row(category: "", monthly: String(format: "%.2f", Double(p))))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let error {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            Text(error).foregroundColor(.red)
                        }
                    }
                }

                Section(header: Text("Budgets by Category")) {
                    ForEach($rows) { $row in
                        HStack {
                            // Category picker/text field hybrid
                            Menu {
                                ForEach(suggestedCategories, id: \.self) { cat in
                                    Button(cat) { row.category = cat }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill").foregroundColor(.secondary)
                                    TextField("Category", text: $row.category)
                                        .textInputAutocapitalization(.words)
                                }
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("$").foregroundColor(.secondary)
                                TextField("0.00", text: $row.monthly)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 90)
                            }
                        }
                    }
                    .onDelete(perform: deleteRows)

                    Button {
                        rows.append(Row(category: "", monthly: ""))
                    } label: {
                        Label("Add Category Budget", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Edit Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving..." : "Save") { Task { await save() } }
                        .disabled(saving)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private func bootstrap() {
        // Start from existing budgets, append a blank row for convenience
        var rs = initialBudgets.map { Row(category: $0.category, monthly: String(format: "%.2f", $0.monthly)) }
        if rs.isEmpty { rs.append(Row(category: "Food", monthly: "")) }
        rows = rs
    }

    private func deleteRows(at offsets: IndexSet) {
        rows.remove(atOffsets: offsets)
    }

    private func save() async {
        error = nil
        saving = true
        do {
            let clean = rows.compactMap { r -> BudgetItemDTO? in
                guard !r.category.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                guard let amt = Double(r.monthly) else { return nil }
                return BudgetItemDTO(id: UUID().uuidString, category: r.category.trimmingCharacters(in: .whitespaces), monthly: amt)
            }
            let api = BudgetsAPI()
            let updated = try await api.set(clean)
            saving = false
            onSaved(updated)
            dismiss()
        } catch {
            saving = false
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    EditBudgetsSheet(
        initialBudgets: [BudgetItemDTO(id: "1", category: "Food", monthly: 400)],
        suggestedCategories: ["Food","Transportation","Shopping"],
        onSaved: { _ in }
    )
}
