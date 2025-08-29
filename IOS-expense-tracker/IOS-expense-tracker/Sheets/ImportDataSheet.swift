import SwiftUI
import UniformTypeIdentifiers

struct ColumnsResp: Decodable {
    let columns: [String]
    let sheets: [String]?
    let suggestedMapping: SuggestedMapping
}
struct SuggestedMapping: Decodable {
    let date: String?
    let description: String?
    let amount: String?
    let type: String?
    let category: String?
    let note: String?
}

struct PreviewResp: Decodable {
    struct Tx: Decodable { let date: String; let description: String; let amount: Double; let type: String?; let category: String?; let note: String? }
    let previewRows: [Tx]
    let totalRows: Int
    let errors: [String]
    let duplicates: [Tx]
    let suggestedMapping: [String:String?]?
}

struct CommitResp: Decodable {
    let success: Bool
    let totalProcessed: Int
    let inserted: Int
    let updated: Int
    let duplicatesSkipped: Int
    let errors: [String]?
}


struct ImportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var status: String = ""

    private let backend = URL(string: "http://192.168.0.119:3000/api/import/preview")!  // change me

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button("Import") { importing = true }
                    .buttonStyle(.borderedProminent)

                if !status.isEmpty {
                    Text(status).font(.footnote).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: allowedTypes(),
                allowsMultipleSelection: false
            ) { (result: Result<[URL], Error>) in
                Task {
                    let firstOnly: Result<URL, Error> = result.flatMap {
                        guard let first = $0.first else {
                            return .failure(NSError(domain: "Importer",
                                                    code: -1,
                                                    userInfo: [NSLocalizedDescriptionKey: "No file selected"]))
                        }
                        return .success(first)
                    }
                    await handleSelection(firstOnly)
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // Build allowed content types safely (no force unwraps).
    private func allowedTypes() -> [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .text, .data, .item]
        if let csvAlt = UTType("public.comma-separated-values-text") { types.append(csvAlt) }
        if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") { types.append(xlsx) }
        if let xls  = UTType("com.microsoft.excel.xls") { types.append(xls) }
        return types
    }

    // MARK: - Selection handler

    private func handleSelection(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let err):
            status = "Import failed: \(err.localizedDescription)"
        case .success(let pickedURL):
            let hadAccess = pickedURL.startAccessingSecurityScopedResource()
            defer { if hadAccess { pickedURL.stopAccessingSecurityScopedResource() } }

            do {
                let sandboxURL = try copyIntoSandbox(pickedURL)
                let mime = guessMIMEType(for: sandboxURL)

                status = "Detecting columns…"
                let cols = try await fetchColumns(for: sandboxURL, mime: mime)

                // Show a mapping editor UI prefilled with cols.suggestedMapping;
                // once the user confirms, call preview:
                let mapping = cols.suggestedMapping
                status = "Generating preview…"
                let preview = try await fetchPreview(fileURL: sandboxURL, mime: mime, mapping: mapping)

                print("First row:", preview.previewRows.first.map { "\($0)" } ?? "none")

                if let first = preview.previewRows.first {
                    print("First row:", first)
                } else {
                    print("First row: none")
                }
                // Present previewRows & duplicates to the user.
                // On user confirmation:
                status = "Committing import…"
                let result = try await commitImport(fileURL: sandboxURL, mime: mime, mapping: mapping, skipDuplicates: true, overwriteDuplicates: false)
                status = "Done. Inserted \(result.inserted). Updated \(result.updated). Skipped \(result.duplicatesSkipped)."

            } catch {
                status = "Error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - File helpers

    private func copyIntoSandbox(_ src: URL) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let target = uniqueURL(base: docs.appendingPathComponent(src.lastPathComponent))
        try FileManager.default.copyItem(at: src, to: target)
        return target
    }

    private func uniqueURL(base: URL) -> URL {
        var url = base
        let ext = url.pathExtension
        let name = url.deletingPathExtension().lastPathComponent
        var i = 1
        while FileManager.default.fileExists(atPath: url.path) {
            i += 1
            url = url.deletingLastPathComponent().appendingPathComponent("\(name) (\(i))").appendingPathExtension(ext)
        }
        return url
    }

    private func guessMIMEType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if let type = UTType(filenameExtension: ext)?.preferredMIMEType {
            return type
        }
        // common fallbacks
        switch ext {
        case "csv": return "text/csv"
        case "tsv": return "text/tab-separated-values"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xls": return "application/vnd.ms-excel"
        case "ofx", "qfx": return "application/x-ofx"
        case "qif": return "application/x-qif"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Multipart upload (streamed)

    private func uploadFile(_ pickedURL: URL, mime: String) async throws -> String {
        let boundary = "----\(UUID().uuidString)"

        var req = URLRequest(url: backend) // your /uploads (or /api/import/preview) URL
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // If you require auth:
        if let token = try? await AuthSession.shared.validAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let bodyURL = try composeMultipartBodyToTempFile(
            fileURL: pickedURL,
            fieldName: "file",                        // MUST MATCH multer upload.single('file')
            filename: pickedURL.lastPathComponent,
            mime: mime,
            boundary: boundary
        )
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: bodyURL)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct UploadResp: Decodable { let uploadId: String? }
        return (try? JSONDecoder().decode(UploadResp.self, from: data).uploadId) ?? "ok"
    }

    private func composeMultipartBodyToTempFile(
        fileURL: URL,
        fieldName: String,
        filename: String,
        mime: String,
        boundary: String
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).body")

        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        let out = try FileHandle(forWritingTo: tmp)
        defer { try? out.close() }


        // Simpler & safer: build with literal \r\n (no replacements)
        let prefixFixed =
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n" +
            "Content-Type: \(mime)\r\n" +
            "\r\n"

        try out.write(contentsOf: Data(prefixFixed.utf8))

        // Stream the file content into the body
        let inFH = try FileHandle(forReadingFrom: fileURL)
        defer { try? inFH.close() }
        while let chunk = try inFH.read(upToCount: 1_048_576), !chunk.isEmpty {
            try out.write(contentsOf: chunk)
        }

        let suffix = "\r\n--\(boundary)--\r\n"
        try out.write(contentsOf: Data(suffix.utf8))
        return tmp
    }
    
    private func multipartTempFile(
        fileURL: URL,
        fieldName: String,
        filename: String,
        mime: String,
        boundary: String,
        fields: [String: String] = [:]
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        let out = try FileHandle(forWritingTo: tmp)
        defer { try? out.close() }

        // write text fields
        for (k, v) in fields {
            let part = "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n"
                + "\(v)\r\n"
            try out.write(contentsOf: Data(part.utf8))
        }

        // file header
        let header = "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
            + "Content-Type: \(mime)\r\n\r\n"
        try out.write(contentsOf: Data(header.utf8))

        // file bytes
        let inFH = try FileHandle(forReadingFrom: fileURL)
        defer { try? inFH.close() }
        while let chunk = try inFH.read(upToCount: 1_048_576), !chunk.isEmpty {
            try out.write(contentsOf: chunk)
        }

        // closing boundary (once)
        try out.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
        return tmp
    }

    private func upload(_ req: URLRequest, fromFile bodyURL: URL) async throws -> (Data, URLResponse) {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 300
        let session = URLSession(configuration: cfg)
        return try await session.upload(for: req, fromFile: bodyURL)
    }

    
    private func fetchColumns(for fileURL: URL, mime: String) async throws -> ColumnsResp {
        let boundary = "----\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "http://192.168.0.119:3000/api/import/columns")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = try? await AuthSession.shared.validAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let bodyURL = try multipartTempFile(
            fileURL: fileURL,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mime: mime,
            boundary: boundary
        )
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: bodyURL)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ColumnsResp.self, from: data)
    }

    private func fetchPreview(
        fileURL: URL,
        mime: String,
        mapping: SuggestedMapping
    ) async throws -> PreviewResp {
        let boundary = "----\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "http://192.168.0.119:3000/api/import/preview")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = try? await AuthSession.shared.validAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let fields: [String:String] = [
            "dateColumn": mapping.date ?? "",
            "descriptionColumn": mapping.description ?? "",
            "amountColumn": mapping.amount ?? "",
            "typeColumn": mapping.type ?? "",
            "categoryColumn": mapping.category ?? "",
            "noteColumn": mapping.note ?? "",
        ]

        let bodyURL = try multipartTempFile(
            fileURL: fileURL,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mime: mime,
            boundary: boundary,
            fields: fields
        )
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: bodyURL)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PreviewResp.self, from: data)
    }
    
    private func commitImport(
        fileURL: URL,
        mime: String,
        mapping: SuggestedMapping,
        skipDuplicates: Bool = true,
        overwriteDuplicates: Bool = false
    ) async throws -> CommitResp {
        let boundary = "----\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "http://192.168.0.119:3000/api/import/commit")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = try? await AuthSession.shared.validAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let fields: [String:String] = [
            "dateColumn": mapping.date ?? "",
            "descriptionColumn": mapping.description ?? "",
            "amountColumn": mapping.amount ?? "",
            "typeColumn": mapping.type ?? "",
            "categoryColumn": mapping.category ?? "",
            "noteColumn": mapping.note ?? "",
            "skipDuplicates": skipDuplicates ? "true" : "false",
            "overwriteDuplicates": overwriteDuplicates ? "true" : "false",
        ]

        let bodyURL = try multipartTempFile(
            fileURL: fileURL,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mime: mime,
            boundary: boundary,
            fields: fields
        )
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: bodyURL)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommitResp.self, from: data)
    }

}

/// Small helper that builds a streamed multipart body.
private struct MultipartFileStream {
    let fileURL: URL
    let fieldName: String
    let filename: String
    let mimeType: String
    let boundary: String

    func makeInputStream() throws -> InputStream {
        let prefix = """
        --\(boundary)\r
        Content-Disposition: form-data; name="\(fieldName)"; filename="\(filename)"\r
        Content-Type: \(mimeType)\r
        \r
        """
        let suffix = "\r\n--\(boundary)--\r\n"

        let fileStream = InputStream(url: fileURL)!
        let prefixData = Data(prefix.utf8)
        let suffixData = Data(suffix.utf8)

        // Chain three streams: prefix → file → suffix
        return ChainedInputStream(streams: [
            InputStream(data: prefixData),
            fileStream,
            InputStream(data: suffixData)
        ])
    }
}

/// Chains multiple InputStreams sequentially.
private final class ChainedInputStream: InputStream {
    private let streams: [InputStream]
    private var idx = 0

    init(streams: [InputStream]) {
        self.streams = streams
        super.init(data: Data()) // unused
    }

    override var streamStatus: Stream.Status {
        streams[idx].streamStatus
    }

    override func open() {
        streams[idx].open()
    }

    override func close() {
        streams[idx].close()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        var total = 0
        while idx < streams.count {
            let n = streams[idx].read(buffer.advanced(by: total), maxLength: len - total)
            if n > 0 {
                total += n
                if total == len { break }
            } else if n == 0 {
                streams[idx].close()
                idx += 1
                if idx < streams.count { streams[idx].open() }
            } else {
                return n // error
            }
        }
        return total
    }

    override var hasBytesAvailable: Bool {
        if idx >= streams.count { return false }
        return streams[idx].hasBytesAvailable
    }
}
