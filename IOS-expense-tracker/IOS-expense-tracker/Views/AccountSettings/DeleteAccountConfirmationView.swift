//
//  DeleteAccountConfirmationView.swift
//  IOS-expense-tracker
//
//  Created by Claude Code on 8/28/25.
//

import SwiftUI

struct DeleteAccountConfirmationView: View {
    @Binding var confirmationText: String
    @Binding var isDeleting: Bool
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let requiredText = "DELETE"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 20)
                
                // Title and Warning
                VStack(spacing: 16) {
                    Text("Delete Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        Text("This action cannot be undone!")
                            .font(.headline)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        
                        Text("Deleting your account will permanently remove:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // What will be deleted
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("All your transactions and financial data")
                    }
                    
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("Categories and budgets")
                    }
                    
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("Recurring bills and subscriptions")
                    }
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("Account settings and preferences")
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Confirmation Input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To confirm deletion, type \"\(requiredText)\" below:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Type \\(requiredText)", text: $confirmationText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            onDelete()
                        }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "trash.fill")
                                }
                                Text(isDeleting ? "Deleting Account..." : "Delete My Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                confirmationText == requiredText && !isDeleting 
                                    ? Color.red 
                                    : Color.gray.opacity(0.3)
                            )
                            .foregroundColor(
                                confirmationText == requiredText && !isDeleting 
                                    ? .white 
                                    : .gray
                            )
                            .cornerRadius(12)
                        }
                        .disabled(confirmationText != requiredText || isDeleting)
                        
                        Button(action: {
                            onCancel()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.secondary.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Confirm Deletion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isDeleting {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }
}

#Preview {
    DeleteAccountConfirmationView(
        confirmationText: .constant(""),
        isDeleting: .constant(false),
        onDelete: {},
        onCancel: {}
    )
}