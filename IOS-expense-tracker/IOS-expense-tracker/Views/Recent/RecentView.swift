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
    @State private var showingClearAllConfirmation = false
    @State private var sortOption: SortOption = .dateNewest
    @AppStorage("recent.sort.option") private var storedSortRaw: String = SortOption.dateNewest.rawValue
    private let api = TransactionsAPI()
    private let iso = ISO8601DateFormatter()

    enum SortOption: String, CaseIterable, Identifiable {
        case dateNewest
        case dateOldest
        case amountHigh
        case amountLow
        case categoryAZ
        case categoryZA

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dateNewest: return "Date (Newest)"
            case .dateOldest: return "Date (Oldest)"
            case .amountHigh: return "Amount (High → Low)"
            case .amountLow: return "Amount (Low → High)"
            case .categoryAZ: return "Category (A → Z)"
            case .categoryZA: return "Category (Z → A)"
            }
        }

        var systemImage: String {
            switch self {
            case .dateNewest: return "calendar.badge.clock"
            case .dateOldest: return "calendar"
            case .amountHigh: return "arrow.down.circle"
            case .amountLow: return "arrow.up.circle"
            case .categoryAZ: return "textformat.abc"
            case .categoryZA: return "textformat.abc.dottedunderline"
            }
        }
    }

    // Quick sort segmented control removed per request; Sort menu retained.

    var body: some View { stackedLayout }

    // MARK: - Stacked (iPhone) Layout
    private var stackedLayout: some View {
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteTransactions)
            }
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            #if os(macOS)
            .listStyle(.inset)
            #endif
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
                        
                        Button {
                            showingClearAllConfirmation = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            // Picker-like menu for sort options
                            ForEach(SortOption.allCases) { option in
                                Button {
                                    sortOption = option
                                    applySort()
                                } label: {
                                    Label(option.title, systemImage: option.systemImage)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                        }
                        EditButton()
                    }
                }
            }
        }
        #if os(macOS)
        .navigationViewStyle(.stack)
        #endif
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
        .onAppear {
            // Restore persisted sort option
            if let restored = SortOption(rawValue: storedSortRaw) {
                sortOption = restored
            }
        }
        .onChange(of: showingImportSheet) { _, isShowing in
            if !isShowing {
                // Refresh transactions after import sheet is dismissed
                Task { await load() }
            }
        }
        .onChange(of: sortOption) { _, newValue in
            applySort()
            storedSortRaw = newValue.rawValue
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
        .alert("Clear All Transactions", isPresented: $showingClearAllConfirmation) {
            Button("Clear All", role: .destructive) {
                clearAllTransactions()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete all transactions? This action cannot be undone.")
        }
    }

    // (Split layout intentionally removed to match iOS single-tab design across platforms.)

    private func load() async {
        loading = true
        error = nil
        do {
            txs = try await api.list(limit: 100, skip: 0)
            applySort()
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
        // Keep list sorted according to selected option
        applySort()
        
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
                    Task { await load() } // or just await load() if `load()` is @MainActor
                    print("🔄 RecentView: Reverted transaction due to server error")
                    self.error = "Failed to update transaction: \(error.localizedDescription)"
                }

            }
        }
    }
    
    private func clearAllTransactions() {
        print("🧹 RecentView: Starting clear all transactions process")
        
        // Clear local UI immediately for responsiveness
        txs.removeAll()
        print("📱 RecentView: Cleared all transactions from local UI")
        
        Task {
            do {
                print("🌐 RecentView: Calling API clear all")
                try await api.clearAll()
                print("✅ RecentView: Successfully cleared all transactions from server")
            } catch {
                print("❌ RecentView: Failed to clear all transactions from server: \(error)")
                // Reload transactions if clearing fails
                await MainActor.run {
                    Task { await load() }
                    self.error = "Failed to clear all transactions: \(error.localizedDescription)"
                    print("🔄 RecentView: Reloaded transactions due to server error")
                }
            }
        }
    }

    private func applySort() {
        switch sortOption {
        case .dateNewest:
            txs.sort { lhs, rhs in
                let ld = iso.date(from: lhs.date) ?? Date.distantPast
                let rd = iso.date(from: rhs.date) ?? Date.distantPast
                return ld > rd
            }
        case .dateOldest:
            txs.sort { lhs, rhs in
                let ld = iso.date(from: lhs.date) ?? Date.distantFuture
                let rd = iso.date(from: rhs.date) ?? Date.distantFuture
                return ld < rd
            }
        case .amountHigh:
            txs.sort { $0.amount > $1.amount }
        case .amountLow:
            txs.sort { $0.amount < $1.amount }
        case .categoryAZ:
            txs.sort { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        case .categoryZA:
            txs.sort { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedDescending }
        }
    }
}
