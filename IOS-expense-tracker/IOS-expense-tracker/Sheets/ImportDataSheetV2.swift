//
//  ImportDataSheetV2.swift
//  IOS-expense-tracker
//
//  Created by Claude on 8/26/25.
//  Alternative implementation with better file handling
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportDataSheetV2: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var fileDataSize: Int = 0
    @State private var isAnalyzing = false
    @State private var showingColumnMapping = false
    @State private var columnResult: FileColumnsResult?
    @State private var importError: String?
    @State private var isAccessingFile = false
    @State private var cachedFileData: Data? // Cache the file data immediately
    @State private var fileSuccessfullyLoaded = false
    @State private var isChangingFile = false // Prevent analysis during file change
    
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
                                Image(systemName: "doc.richtext")
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
                            
                            if fileDataSize > 0 {
                                Text("File size: \(fileDataSize) bytes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Button("Change File") {
                                    print("🔄 Manual Change File button pressed")
                                    // Set flag to prevent analysis during file change
                                    isChangingFile = true
                                    
                                    // Reset everything
                                    selectedFileURL = nil
                                    selectedFileName = ""
                                    fileDataSize = 0
                                    cachedFileData = nil
                                    fileSuccessfullyLoaded = false
                                    columnResult = nil
                                    importError = nil
                                    isAnalyzing = false // Make sure we're not stuck in analyzing state
                                    
                                    // Small delay to ensure state is updated before showing picker
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showingFilePicker = true
                                        isChangingFile = false
                                    }
                                }
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                if cachedFileData != nil && !selectedFileName.isEmpty && importError == nil && !isChangingFile {
                                    Button("Continue") {
                                        Task { await analyzeFile() }
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.blue)
                                    .cornerRadius(8)
                                }
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
            Task { @MainActor in
                handleFileSelection(result)
            }
        }
        .sheet(isPresented: $showingColumnMapping) {
            if let columnResult = columnResult,
               let fileURL = selectedFileURL {
                ColumnMappingSheetV2(
                    fileName: selectedFileName,
                    fileURL: fileURL,
                    columnResult: columnResult
                ) {
                    dismiss()
                }
            }
        }
    }
    
    private func resetSelection() {
        print("🔄 Resetting file selection")
        print("🔄 Current selectedFileName before reset: '\(selectedFileName)'")
        print("🔄 Current selectedFileURL before reset: \(selectedFileURL?.lastPathComponent ?? "nil")")
        print("🔄 fileSuccessfullyLoaded: \(fileSuccessfullyLoaded)")
        
        // Don't reset if we have successfully loaded data and this seems like an unwanted reset
        if fileSuccessfullyLoaded && cachedFileData != nil {
            print("🛡️ Preventing reset - file was successfully loaded and cached")
            return
        }
        
        selectedFileURL = nil
        selectedFileName = ""
        fileDataSize = 0
        cachedFileData = nil
        fileSuccessfullyLoaded = false
        columnResult = nil
        importError = nil
        
        print("🔄 Reset completed")
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { 
                print("❌ No URL in file selection result")
                return 
            }
            
            print("🔍 Processing file selection for: \(url.lastPathComponent)")
            print("🔍 URL scheme: \(url.scheme ?? "none")")
            print("🔍 URL path: \(url.path)")
            
            // Clear any existing errors first
            importError = nil
            
            // Set the basic info immediately
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
            // Immediately try to read the file to test access AND cache it
            if let testData = readFileDataImmediately(from: url) {
                fileDataSize = testData.count
                cachedFileData = testData // Cache the data immediately!
                fileSuccessfullyLoaded = true
                print("📁 File successfully accessed and cached: \(selectedFileName) (\(fileDataSize) bytes)")
            } else {
                print("⚠️ File access test failed")
                fileDataSize = 0
                cachedFileData = nil
                fileSuccessfullyLoaded = false
                
                // Show helpful error message about file access
                importError = "File access denied. Please try: 1) Save the file to 'On My iPhone' instead of iCloud, 2) Use a different app to export/save the file, or 3) Copy the file to a different location."
            }
            
        case .failure(let error):
            print("❌ File selection failed: \(error)")
            importError = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func readFileDataImmediately(from url: URL) -> Data? {
        print("🔍 Testing immediate file access for: \(url.lastPathComponent)")
        
        // Start accessing the security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        print("🔍 Security scoped resource access: \(accessing)")
        
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("✅ Immediate file access successful: \(data.count) bytes")
            return data
        } catch {
            print("❌ Immediate file access failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func readFileData(from url: URL) -> Data? {
        print("🔍 Attempting to read file data from: \(url.lastPathComponent)")
        
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Cannot access security scoped resource for: \(url.lastPathComponent)")
            return nil
        }
        
        defer { 
            url.stopAccessingSecurityScopedResource() 
            print("🔒 Released security scoped resource")
        }
        
        do {
            // Check if file exists and is readable
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ File does not exist at path: \(url.path)")
                return nil
            }
            
            print("🔍 File exists, attempting to read...")
            let data = try Data(contentsOf: url)
            print("✅ Successfully read \(data.count) bytes from file")
            
            // Verify the data is not empty
            if data.isEmpty {
                print("⚠️ File data is empty")
                return nil
            }
            
            return data
        } catch {
            print("❌ Failed to read file: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func analyzeFile() async {
        print("🔍 analyzeFile called")
        print("🔍 selectedFileName: '\(selectedFileName)'")
        print("🔍 selectedFileURL: \(selectedFileURL?.lastPathComponent ?? "nil")")
        print("🔍 cachedFileData available: \(cachedFileData != nil)")
        print("🔍 cachedFileData size: \(cachedFileData?.count ?? -1)")
        print("🔍 fileSuccessfullyLoaded: \(fileSuccessfullyLoaded)")
        
        // Early guards - don't proceed if state is invalid
        guard !isChangingFile else {
            print("❌ analyzeFile: Currently changing files - ignoring call")
            return
        }
        
        guard !selectedFileName.isEmpty else {
            print("❌ analyzeFile: No filename - should not have been called")
            await MainActor.run {
                importError = "Invalid state: No file selected"
            }
            return
        }
        
        // Try to get cached data first, if not available try to re-read from URL
        var data: Data?
        
        if let cachedData = cachedFileData {
            data = cachedData
            print("✅ Using cached file data")
        } else if let fileURL = selectedFileURL, !selectedFileName.isEmpty {
            print("🔄 No cached data, attempting to re-read file...")
            data = readFileDataImmediately(from: fileURL)
            if let readData = data {
                cachedFileData = readData // Cache it again
                print("✅ File re-read successful, cached again")
            }
        }
        
        guard let fileData = data, !selectedFileName.isEmpty else {
            await MainActor.run {
                importError = "No file data available. Please choose a file first."
            }
            print("❌ analyzeFile: No data to analyze")
            return
        }
        
        await MainActor.run {
            isAnalyzing = true
            importError = nil
        }
        
        print("✅ File data ready (\(fileData.count) bytes), analyzing...")
        
        do {
            let result = try await api.getFileColumns(fileData: fileData, fileName: selectedFileName)
            print("✅ Column analysis successful")
            await MainActor.run {
                columnResult = result
                showingColumnMapping = true
                isAnalyzing = false
            }
        } catch {
            print("❌ File analysis failed: \(error)")
            await MainActor.run {
                importError = "Failed to analyze file: \(error.localizedDescription)"
                isAnalyzing = false
            }
        }
    }
}

struct ColumnMappingSheetV2: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    let fileURL: URL
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
    
    init(fileName: String, fileURL: URL, columnResult: FileColumnsResult, onCompletion: @escaping () -> Void) {
        self.fileName = fileName
        self.fileURL = fileURL
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
    
    private func readFileData() -> Data? {
        guard fileURL.startAccessingSecurityScopedResource() else {
            return nil
        }
        
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        return try? Data(contentsOf: fileURL)
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
            if let importResult = importResult,
               let fileData = readFileData() {
                ImportPreviewSheetV2(
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
        
        guard let fileData = readFileData() else {
            importError = "Failed to read file data"
            isPreviewingImport = false
            return
        }
        
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

// Reuse the existing ImportPreviewSheet but with fileData passed in
typealias ImportPreviewSheetV2 = ImportPreviewSheet

#Preview {
    ImportDataSheetV2()
}
