import SwiftUI

struct AddTransactionSheet: View {
    enum Kind { case expense, income }
    let kind: Kind
    var onSaved: (TransactionDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var isSaving = false
    @State private var error: String?

    private let api = TransactionsAPI()
    private var typeString: String { kind == .expense ? "expense" : "income" }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Category", text: $category)
                    TextField("Note (optional)", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle(kind == .expense ? "Add Expense" : "Add Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || Double(amount) == nil || category.isEmpty)
                }
            }
        }
    }

    private func save() async {
        guard let amt = Double(amount) else { return }
        isSaving = true; error = nil
        let body = CreateTransactionBody(
            type: typeString,
            amount: amt,
            category: category.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note,
            date: ISO8601DateFormatter().string(from: date)
        )
        do {
            let created = try await api.create(body)
            await MainActor.run {
                onSaved(created)
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.isSaving = false
                
                // Handle authentication errors specifically
                if let authError = error as? AuthError {
                    switch authError {
                    case .notAuthenticated:
                        self.error = "Please sign in again to continue."
                        
                    case .server(let message):
                        self.error = "Server error: \(message)"
                        
                    case .networkError:
                        self.error = "Network error. Please check your connection."
                        
                    case .decodingError:
                        self.error = "Data error. Please try again."
                        
                    case .invalidCredentials:
                        self.error = "Incorrect email or password. Please try again."
                        
                    case .userExists:
                        self.error = "An account with this email already exists."
                        
                    case .weakPassword:
                        self.error = "That password is too weak. Use at least 8 characters with numbers and symbols."
                        
                    case .invalidEmail:
                        self.error = "That email address looks invalid."
                        
                    case .badResponse:
                        self.error = "Unexpected server response. Please try again."
                    }
                } else if error.localizedDescription.contains("401") ||
                          error.localizedDescription.contains("unauthorized") ||
                          error.localizedDescription.contains("authentication") {
                    self.error = "Authentication failed. Please sign in again."
                    // Optionally trigger re-authentication here
                } else {
                    self.error = "Failed to save transaction: \(error.localizedDescription)"
                }
            }
        }
    }
}
