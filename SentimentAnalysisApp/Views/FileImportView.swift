import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    @ObservedObject var viewModel: FileImportViewModel
    var onContinue: () -> Void
    @State private var showFileImporter = false
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack {
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, UTType(filenameExtension: "xlsx")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 32) {
            headerSection
            descriptionSection
            fileSelectionSection
            loadingSection
            errorSection
            continueButton
        }
        .frame(maxWidth: 600)
        .padding()
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Import File")
                .font(.title)
                .fontWeight(.bold)
        }
    }
    
    private var descriptionSection: some View {
        Text("Select a CSV or XLSX file containing the sentiments you want to analyze. You'll be able to choose which column to analyze.")
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .padding(.horizontal)
    }
    
    private var fileSelectionSection: some View {
        VStack(spacing: 20) {
            if let fileURL = viewModel.fileURL {
                filePreviewCard(fileURL: fileURL)
            } else {
                fileSelectionButton
            }
        }
    }
    
    private func filePreviewCard(fileURL: URL) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileURL.lastPathComponent)
                        .font(.headline)
                    Text("File size: \(formatFileSize(fileURL))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: {
                        showFileImporter = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.removeFile()
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var fileSelectionButton: some View {
        Button(action: {
            showFileImporter = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("Choose CSV or XLSX File")
                    .font(.headline)
                Text("Click or drag a file here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(isTargeted ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onDrop(
            of: [UTType.commaSeparatedText, UTType(filenameExtension: "xlsx")!],
            isTargeted: $isTargeted
        ) { providers in
            if let provider = providers.first {
                _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: provider.registeredTypeIdentifiers.first ?? "") { url, inPlace, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            viewModel.importFile(url: url)
                        }
                    }
                }
                return true
            }
            return false
        }
    }
    
    private var loadingSection: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Parsing file...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var errorSection: some View {
        Group {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.body)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var continueButton: some View {
        Button("Continue to Select Column") {
            onContinue()
        }
        .disabled(viewModel.columns.isEmpty)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    private func formatFileSize(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            // Ignore error
        }
        return "Unknown size"
    }
}

struct TableRow: Identifiable {
    let id: Int
    let values: [String]
    let isHeader: Bool
    
    func cellValue(for index: Int) -> String {
        values[index]
    }
}

struct DynamicTableView: View {
    let columns: [String]
    let data: [[String]]
    @Binding var selectedColumn: String?
    
    var body: some View {
        if columns.isEmpty {
            EmptyStateView()
        } else {
            Table(tableData) {
                TableColumnForEach(columns, id: \.self) { column in
                    TableColumn(column) { (row: TableRow) in
                        if let index = columns.firstIndex(of: column) {
                            cellContent(row: row, columnIndex: index, columnName: column)
                        }
                    }
                }
            }
        }
    }
    
    private var tableData: [TableRow] {
        let maxRows = min(data.count, 6)
        return (0..<maxRows).map { rowIndex in
            let rowData = data[rowIndex]
            return TableRow(
                id: rowIndex,
                values: rowData,
                isHeader: rowIndex == 0
            )
        }
    }
    
    private func cellContent(row: TableRow, columnIndex: Int, columnName: String) -> some View {
        Text(row.cellValue(for: columnIndex))
            .font(.system(size: 11, weight: row.isHeader ? .semibold : .regular))
            .foregroundColor(row.isHeader ? .primary : .secondary)
            .lineLimit(3)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(cellBackground(columnName: columnName))
            .overlay(cellBorder(columnName: columnName))
            .onTapGesture {
                selectedColumn = columnName
            }
    }
    
    private func cellBackground(columnName: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(selectedColumn == columnName ? Color.blue.opacity(0.15) : Color.clear)
    }
    
    private func cellBorder(columnName: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(selectedColumn == columnName ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Image(systemName: "tablecells")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No data to display")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
} 