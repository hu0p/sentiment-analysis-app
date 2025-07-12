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
            columnSelectionSection
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
    
    private var columnSelectionSection: some View {
        Group {
            if !viewModel.columns.isEmpty {
                VStack(spacing: 16) {
                    Text("Select column to analyze:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    dataPreviewTable
                    
                    selectedColumnIndicator
                }
            }
        }
    }
    
    private var dataPreviewTable: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.previewData.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cellValue in
                            cellButton(rowIndex: rowIndex, colIndex: colIndex, cellValue: cellValue)
                        }
                    }
                    .background(rowIndex == 0 ? Color.blue.opacity(0.08) : Color.clear)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .offset(y: rowIndex == 0 ? 0 : -0.5),
                        alignment: .top
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxHeight: 200)
        .clipped()
    }
    
    private func cellButton(rowIndex: Int, colIndex: Int, cellValue: String) -> some View {
        ZStack {
            // Background and selection styling
            RoundedRectangle(cornerRadius: 3)
                .fill(viewModel.selectedColumn == viewModel.columns[colIndex] ? Color.blue.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(viewModel.selectedColumn == viewModel.columns[colIndex] ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
            
            // Content
            HStack {
                Text(cellValue)
                    .font(.system(size: 11, weight: rowIndex == 0 ? .semibold : .regular))
                    .foregroundColor(rowIndex == 0 ? .primary : .secondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(width: 100, height: 60)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedColumn = viewModel.columns[colIndex]
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1)
                .offset(x: -0.5),
            alignment: .leading
        )
    }
    
    private var selectedColumnIndicator: some View {
        Group {
            if let selectedColumn = viewModel.selectedColumn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Selected: \(selectedColumn)")
                        .font(.body)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var continueButton: some View {
        Button("Start Analysis") {
            onContinue()
        }
        .disabled(viewModel.selectedColumn == nil)
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