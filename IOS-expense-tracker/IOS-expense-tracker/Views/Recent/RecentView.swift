//
//  RecentView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

struct RecentView: View {
    @State private var txs: [TransactionDTO] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showingEditTransaction = false
    @State private var selectedTransaction: TransactionDTO?
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    private let api = TransactionsAPI()

    var body: some View {
        NavigationView {
            List {
                if let error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 8)
                }
                
                if loading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading transactions...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                ForEach(txs) { t in
                    TransactionRowDetailed(
                        transaction: t,
                        onEdit: {
                            selectedTransaction = t
                            showingEditTransaction = true
                        },
                        onDelete: {
                            selectedTransaction = t
                            showingDeleteConfirmation = true
                        }
                    )
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteTransactions)
            }
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await load() }
            .task { await load() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button {
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Button {
                            showingExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingEditTransaction) {
            if let transaction = selectedTransaction {
                EditTransactionSheet(transaction: transaction) { updatedTransaction in
                    updateTransaction(updatedTransaction)
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataSheet()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportDataSheet()
        }
        .onChange(of: showingImportSheet) { _, isShowing in
            if !isShowing {
                // Refresh transactions after import sheet is dismissed
                Task { await load() }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let transaction = selectedTransaction {
                    deleteTransaction(transaction)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            txs = try await api.list(limit: 100, skip: 0)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
    
    private func deleteTransactions(offsets: IndexSet) {
        for index in offsets {
            deleteTransaction(txs[index])
        }
    }
    
    private func deleteTransaction(_ transaction: TransactionDTO) {
        print("🗑️ RecentTransactionsView: Starting delete process for transaction: \(transaction.id)")
        
        // Remove from local array immediately for UI responsiveness
        txs.removeAll { $0.id == transaction.id }
        print("📱 RecentTransactionsView: Removed transaction from local UI")
        
        Task {
            do {
                print("🌐 RecentTransactionsView: Calling API delete for transaction: \(transaction.id)")
                try await api.delete(transaction.id)
                print("✅ RecentTransactionsView: Successfully deleted transaction from server: \(transaction.id)")
            } catch {
                print("❌ RecentTransactionsView: Failed to delete transaction from server: \(error)")
                // Re-add transaction if deletion fails
                await MainActor.run {
                    txs.append(transaction)
                    self.error = "Failed to delete transaction: \(error.localizedDescription)"
                    print("🔄 RecentTransactionsView: Re-added transaction to UI due to server error")
                }
            }
        }
    }
    
    private func updateTransaction(_ transaction: TransactionDTO) {
        print("📝 RecentView: Starting update process for transaction: \(transaction.id)")
        
        // Update local UI immediately for responsiveness
        if let index = txs.firstIndex(where: { $0.id == transaction.id }) {
            txs[index] = transaction
            print("📱 RecentView: Updated transaction in local UI")
        }
        
        Task {
            do {
                print("🌐 RecentView: Calling API update for transaction: \(transaction.id)")
                let updatedTransaction = try await api.update(transaction.id, CreateTransactionBody(
                    type: transaction.type,
                    amount: transaction.amount,
                    category: transaction.category,
                    note: transaction.note,
                    date: transaction.date
                ))
                print("✅ RecentView: Successfully updated transaction on server: \(updatedTransaction.id)")
            } catch {
                print("❌ RecentView: Failed to update transaction on server: \(error)")
                // Revert the local change if server update fails
                await MainActor.run {
                    if let index = txs.firstIndex(where: { $0.id == transaction.id }) {
                        // Reload the transaction list to get the original data
                        Task { await load() }
                        print("🔄 RecentView: Reverted transaction due to server error")
                    }
                    self.error = "Failed to update transaction: \(error.localizedDescription)"
                }
            }
        }
    }
}
