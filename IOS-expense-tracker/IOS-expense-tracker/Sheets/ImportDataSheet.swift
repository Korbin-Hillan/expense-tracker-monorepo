//
//  ImportDataSheet.swift
//  IOS-expense-tracker
//
//  Created by Claude on 8/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var fileData: Data?
    @State private var isAnalyzing = false
    @State private var showingColumnMapping = false
    @State private var columnResult: FileColumnsResult?
    @State private var importError: String?
    
    private let api = TransactionsAPI()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Import Bank Statement") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Import transactions from your bank or credit card statements.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        Text("Supported formats:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("CSV files (.csv)")
                            }
                            HStack {
                                Image(systemName: "doc.spreadsheet")
                                    .foregroundColor(.green)
                                Text("Excel files (.xlsx, .xls)")
                            }
                        }
                        .font(.subheadline)
                    }
                }
                
                Section("Select File") {
                    if selectedFileName.isEmpty {
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Choose File")
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.blue)
                                Text(selectedFileName)
                                    .fontWeight(.medium)
                                Spacer()
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            // Debug info
                            Text("File size: \(fileData?.count ?? 0) bytes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Change File") {
                                    showingFilePicker = true
                                }
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Button("Continue") {
                                    print("🎯 Continue button pressed")
                                    print("🎯 fileData is nil: \(fileData == nil)")
                                    print("🎯 fileData size: \(fileData?.count ?? -1)")
                                    Task { await analyzeFile() }
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(fileData != nil && !isAnalyzing ? .blue : .gray)
                                .cornerRadius(8)
                                .disabled(fileData == nil || isAnalyzing)
                            }
                        }
                    }
                }
                
                if let error = importError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section("Tips for Best Results") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Ensure your file has clear column headers (Date, Description, Amount, etc.)")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Use your bank's official export format when possible")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Remove any summary rows or totals before importing")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("The app will automatically detect and skip duplicate transactions")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .text,
                UTType("public.comma-separated-values-text") ?? .data,
                UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
                UTType("com.microsoft.excel.xls") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingColumnMapping) {
            if let columnResult = columnResult,
               let fileData = fileData {
                ColumnMappingSheet(
                    fileName: selectedFileName,
                    fileData: fileData,
                    columnResult: columnResult
                ) {
                    // On completion
                    dismiss()
                }
            }
        }
    }
    
    private func resetSelection() {
        print("🔄 Resetting file selection")
        selectedFileURL = nil
        selectedFileName = ""
        fileData = nil
        columnResult = nil
        importError = nil
    }
    @MainActor
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access selected file"
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                fileData = data
                importError = nil
                print("📁 File loaded: \(selectedFileName) (\(data.count) bytes)")
                print("📁 FileData state after loading: \(fileData != nil ? "not nil" : "nil")")
                
                // Stop accessing after we've read the data
                url.stopAccessingSecurityScopedResource()
            } catch {
                url.stopAccessingSecurityScopedResource()
                print("❌ Failed to read file: \(error)")
                importError = "Failed to read file: \(error.localizedDescription)"
                resetSelection()
            }
            
        case .failure(let error):
            importError = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func analyzeFile() async {
        print("🔍 analyzeFile called")
        print("🔍 fileData is nil: \(fileData == nil)")
        print("🔍 fileData size: \(fileData?.count ?? -1)")
        
        guard let fileData = fileData else {
            print("❌ No file data available in analyzeFile")
            importError = "No file data available"
            return
        }
        
        print("✅ File data is available, starting analysis...")
        isAnalyzing = true
        importError = nil
        
        do {
            columnResult = try await api.getFileColumns(fileData: fileData, fileName: selectedFileName)
            print("✅ Column analysis successful")
            showingColumnMapping = true
        } catch {
            print("❌ File analysis failed: \(error)")
            importError = "Failed to analyze file: \(error.localizedDescription)"
        }
        
        isAnalyzing = false
        
    }
}

struct ColumnMappingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    let fileData: Data
    let columnResult: FileColumnsResult
    let onCompletion: () -> Void
    
    @State private var dateColumn: String
    @State private var descriptionColumn: String
    @State private var amountColumn: String
    @State private var typeColumn: String = "None"
    @State private var categoryColumn: String = "None"
    @State private var noteColumn: String = "None"
    @State private var selectedSheet: String = ""
    @State private var skipDuplicates: Bool = true
    
    @State private var isPreviewingImport = false
    @State private var showingPreview = false
    @State private var importResult: ImportResult?
    @State private var importError: String?
    
    private let api = TransactionsAPI()
    
    init(fileName: String, fileData: Data, columnResult: FileColumnsResult, onCompletion: @escaping () -> Void) {
        self.fileName = fileName
        self.fileData = fileData
        self.columnResult = columnResult
        self.onCompletion = onCompletion
        
        // Initialize with suggested mappings
        _dateColumn = State(initialValue: columnResult.suggestedMapping.date ?? columnResult.columns.first ?? "")
        _descriptionColumn = State(initialValue: columnResult.suggestedMapping.description ?? columnResult.columns.first ?? "")
        _amountColumn = State(initialValue: columnResult.suggestedMapping.amount ?? columnResult.columns.first ?? "")
        _selectedSheet = State(initialValue: columnResult.sheets.first ?? "")
        
        if let suggestedType = columnResult.suggestedMapping.type {
            _typeColumn = State(initialValue: suggestedType)
        }
        if let suggestedCategory = columnResult.suggestedMapping.category {
            _categoryColumn = State(initialValue: suggestedCategory)
        }
        if let suggestedNote = columnResult.suggestedMapping.note {
            _noteColumn = State(initialValue: suggestedNote)
        }
    }
    
    private var columnOptions: [String] {
        ["None"] + columnResult.columns
    }
    
    private var isValidMapping: Bool {
        !dateColumn.isEmpty && !descriptionColumn.isEmpty && !amountColumn.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("File Information") {
                    HStack {
                        Text("File:")
                        Spacer()
                        Text(fileName)
                            .foregroundColor(.secondary)
                    }
                    
                    if !columnResult.sheets.isEmpty {
                        Picker("Sheet", selection: $selectedSheet) {
                            ForEach(columnResult.sheets, id: \.self) { sheet in
                                Text(sheet).tag(sheet)
                            }
                        }
                    }
                }
                
                Section("Required Columns") {
                    Picker("Date Column", selection: $dateColumn) {
                        ForEach(columnResult.columns, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                    
                    Picker("Description Column", selection: $descriptionColumn) {
                        ForEach(columnResult.columns, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                    
                    Picker("Amount Column", selection: $amountColumn) {
                        ForEach(columnResult.columns, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                }
                
                Section("Optional Columns") {
                    Picker("Transaction Type", selection: $typeColumn) {
                        ForEach(columnOptions, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                    
                    Picker("Category", selection: $categoryColumn) {
                        ForEach(columnOptions, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                    
                    Picker("Note/Memo", selection: $noteColumn) {
                        ForEach(columnOptions, id: \.self) { column in
                            Text(column).tag(column)
                        }
                    }
                }
                
                Section("Import Settings") {
                    Toggle("Skip Duplicate Transactions", isOn: $skipDuplicates)
                }
                
                if let error = importError {
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
            .navigationTitle("Column Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Preview") {
                        Task { await previewImport() }
                    }
                    .disabled(!isValidMapping || isPreviewingImport)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let importResult = importResult {
                ImportPreviewSheet(
                    fileName: fileName,
                    fileData: fileData,
                    mapping: createMapping(),
                    selectedSheet: selectedSheet.isEmpty ? nil : selectedSheet,
                    skipDuplicates: skipDuplicates,
                    importResult: importResult
                ) {
                    onCompletion()
                }
            }
        }
    }
    
    private func createMapping() -> ColumnMapping {
        return ColumnMapping(
            dateColumn: dateColumn,
            descriptionColumn: descriptionColumn,
            amountColumn: amountColumn,
            typeColumn: typeColumn == "None" ? nil : typeColumn,
            categoryColumn: categoryColumn == "None" ? nil : categoryColumn,
            noteColumn: noteColumn == "None" ? nil : noteColumn
        )
    }
    
    private func previewImport() async {
        isPreviewingImport = true
        importError = nil
        
        do {
            importResult = try await api.previewImport(
                fileData: fileData,
                fileName: fileName,
                mapping: createMapping(),
                sheetName: selectedSheet.isEmpty ? nil : selectedSheet
            )
            showingPreview = true
        } catch {
            importError = "Preview failed: \(error.localizedDescription)"
        }
        
        isPreviewingImport = false
    }
}

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    let fileData: Data
    let mapping: ColumnMapping
    let selectedSheet: String?
    let skipDuplicates: Bool
    let importResult: ImportResult
    let onCompletion: () -> Void
    
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var finalResult: ImportCommitResult?
    @State private var importError: String?
    
    private let api = TransactionsAPI()
    
    var body: some View {
        NavigationView {
            if importComplete, let result = finalResult {
                // Success screen
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 8) {
                        Text("Import Complete!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Successfully imported \(result.inserted) transactions")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Processed:")
                            Spacer()
                            Text("\(result.totalProcessed)")
                        }
                        HStack {
                            Text("Imported:")
                            Spacer()
                            Text("\(result.inserted)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        if result.duplicatesSkipped > 0 {
                            HStack {
                                Text("Duplicates Skipped:")
                                Spacer()
                                Text("\(result.duplicatesSkipped)")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Button("Done") {
                        onCompletion()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .cornerRadius(8)
                }
                .padding()
                .navigationTitle("Import Complete")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Preview screen
                Form {
                    Section("Import Summary") {
                        HStack {
                            Text("Total Rows:")
                            Spacer()
                            Text("\(importResult.totalRows)")
                        }
                        HStack {
                            Text("Valid Transactions:")
                            Spacer()
                            Text("\(importResult.validTransactions)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        if importResult.errors.count > 0 {
                            HStack {
                                Text("Errors:")
                                Spacer()
                                Text("\(importResult.errors.count)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                        if importResult.duplicates.count > 0 {
                            HStack {
                                Text("Potential Duplicates:")
                                Spacer()
                                Text("\(importResult.duplicates.count)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    if !importResult.preview.isEmpty {
                        Section("Preview (First 10 Transactions)") {
                            ForEach(Array(importResult.preview.enumerated()), id: \.offset) { index, transaction in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(transaction.description)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("$\(transaction.amount, specifier: "%.2f")")
                                            .fontWeight(.semibold)
                                    }
                                    HStack {
                                        Text(transaction.date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let category = transaction.category {
                                            Text("• \(category)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if let type = transaction.type {
                                            Text(type.capitalized)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(type == "income" ? .green.opacity(0.2) : .red.opacity(0.2))
                                                .foregroundColor(type == "income" ? .green : .red)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    
                    if !importResult.errors.isEmpty {
                        Section("Errors Found") {
                            ForEach(Array(importResult.errors.prefix(5).enumerated()), id: \.offset) { index, error in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Row \(error.row): \(error.message)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            if importResult.errors.count > 5 {
                                Text("...and \(importResult.errors.count - 5) more errors")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let error = importError {
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
                .navigationTitle("Preview Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            dismiss()
                        }
                        .disabled(isImporting)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Import") {
                            Task { await commitImport() }
                        }
                        .disabled(isImporting || importResult.validTransactions == 0)
                    }
                }
            }
        }
    }
    
    private func commitImport() async {
        isImporting = true
        importError = nil
        
        do {
            finalResult = try await api.commitImport(
                fileData: fileData,
                fileName: fileName,
                mapping: mapping,
                skipDuplicates: skipDuplicates,
                sheetName: selectedSheet
            )
            importComplete = true
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
        
        isImporting = false
    }
}

#Preview {
    ImportDataSheet()
}
