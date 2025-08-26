//
//  ImportDataShareSheet.swift
//  IOS-expense-tracker
//
//  Alternative import using Share Sheet instead of File Picker
//

import SwiftUI

struct ImportDataShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Import Using Share")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("To import your Discover CSV file:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Open your Discover CSV file in the Files app")
                        }
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Tap the Share button (↗️)")
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Choose 'Expense Tracker' from the share options")
                        }
                        
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("The import process will start automatically")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Text("This method works better with files downloaded from bank websites.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("Try File Picker Instead") {
                    // You can switch back to the file picker method
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            .padding()
            .navigationTitle("Alternative Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImportDataShareSheet()
}