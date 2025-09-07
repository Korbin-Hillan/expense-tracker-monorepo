//
//  ExportDataSheet.swift
//  IOS-expense-tracker
//
//  Created by Claude on 8/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .csv
    @State private var selectedType: String = "all"
    @State private var selectedCategory: String = "all"
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var useCustomDateRange = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var summary: TransactionSummary?
    @State private var isLoadingSummary = false
    
    private let api = TransactionsAPI()
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case excel = "Excel"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .excel: return "xlsx"
            }
        }
        
        var utType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .excel: return UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data
            }
        }
    }
    
    let transactionTypes = ["all", "expense", "income"]
    let categories = ["all", "Food", "Transportation", "Entertainment", "Shopping", "Bills", "Health", "Education", "Travel", "Other"] // You might want to make this dynamic
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Filters") {
                    Picker("Transaction Type", selection: $selectedType) {
                        ForEach(transactionTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category.capitalized).tag(category)
                        }
                    }
                    
                    Toggle("Custom Date Range", isOn: $useCustomDateRange)
                    
                    if useCustomDateRange {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                if let summary = summary {
                    Section("Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Transactions:")
                                Spacer()
                                Text("\(summary.totalTransactions)")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Total Income:")
                                Spacer()
                                Text("$\(summary.totalIncome, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Total Expenses:")
                                Spacer()
                                Text("$\(summary.totalExpenses, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            
                            HStack {
                                Text("Net Amount:")
                                Spacer()
                                Text("$\(summary.netAmount, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(summary.netAmount >= 0 ? .green : .red)
                            }
                            
                            if summary.dateRange.from != "N/A" {
                                HStack {
                                    Text("Date Range:")
                                    Spacer()
                                    Text("\(summary.dateRange.from) to \(summary.dateRange.to)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if let error = exportError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        Task { await exportData() }
                    }
                    .disabled(isExporting)
                }
            }
            .task {
                await loadSummary()
            }
            .onChange(of: selectedType) { _, _ in
                Task { await loadSummary() }
            }
            .onChange(of: selectedCategory) { _, _ in
                Task { await loadSummary() }
            }
            .onChange(of: useCustomDateRange) { _, _ in
                Task { await loadSummary() }
            }
            .onChange(of: startDate) { _, _ in
                if useCustomDateRange {
                    Task { await loadSummary() }
                }
            }
            .onChange(of: endDate) { _, _ in
                if useCustomDateRange {
                    Task { await loadSummary() }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exportedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
    }
    
    private func loadSummary() async {
        isLoadingSummary = true
        exportError = nil
        
        do {
            let startDateString = useCustomDateRange ? ISO8601DateFormatter().string(from: startDate) : nil
            let endDateString = useCustomDateRange ? ISO8601DateFormatter().string(from: endDate) : nil
            
            summary = try await api.getSummary(
                startDate: startDateString,
                endDate: endDateString,
                category: selectedCategory,
                type: selectedType
            )
        } catch {
            exportError = "Failed to load summary: \(error.localizedDescription)"
        }
        
        isLoadingSummary = false
    }
    
    private func exportData() async {
        isExporting = true
        exportError = nil
        
        do {
            let startDateString = useCustomDateRange ? ISO8601DateFormatter().string(from: startDate) : nil
            let endDateString = useCustomDateRange ? ISO8601DateFormatter().string(from: endDate) : nil
            
            let data: Data
            switch selectedFormat {
            case .csv:
                data = try await api.exportCSV(
                    startDate: startDateString,
                    endDate: endDateString,
                    category: selectedCategory,
                    type: selectedType
                )
            case .excel:
                data = try await api.exportExcel(
                    startDate: startDateString,
                    endDate: endDateString,
                    category: selectedCategory,
                    type: selectedType
                )
            }
            
            // Save to temporary file
            let fileName = "transactions_export_\(Int(Date().timeIntervalSince1970)).\(selectedFormat.fileExtension)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: tempURL)
            
            await MainActor.run {
                exportedFileURL = tempURL
                showingShareSheet = true
                dismiss()
            }
        } catch {
            await MainActor.run {
                exportError = "Export failed: \(error.localizedDescription)"
            }
        }
        
        isExporting = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportDataSheet()
}