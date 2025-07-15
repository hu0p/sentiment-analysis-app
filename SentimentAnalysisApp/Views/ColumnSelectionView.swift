import SwiftUI

struct ColumnPreviewRow: Identifiable {
    let id: Int
    let value: String
    var index: Int { id }
}

struct ColumnSelectionView: View {
    @ObservedObject var appFlowViewModel: AppFlowViewModel
    @ObservedObject var fileImportViewModel: FileImportViewModel
    @ObservedObject var analysisViewModel: AnalysisViewModel
    var selectedModel: String
    var additionalContext: String
    
    // Extracted computed property for preview table data
    private var previewTableData: [ColumnPreviewRow] {
        guard let selectedColumn = fileImportViewModel.selectedColumn,
              let columnIndex = fileImportViewModel.columns.firstIndex(of: selectedColumn) else {
            return []
        }
        let validRows = fileImportViewModel.previewData.enumerated().compactMap { index, row in
            columnIndex < row.count ? (index, row[columnIndex]) : nil
        }.prefix(25)
        return validRows.map { (originalIndex, cellValue) in
            ColumnPreviewRow(id: originalIndex, value: cellValue)
        }
    }
    
    // Helper for the Table view
    @ViewBuilder
    private func previewTable(selectedColumn: String) -> some View {
        Table(previewTableData) {
            TableColumn("Row") { row in
                Text("\(row.index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(50)
            
            TableColumn(selectedColumn) { row in
                Text(row.value)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 120)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    var body: some View {
        print("[ColumnSelectionView] selectedColumn: \(String(describing: fileImportViewModel.selectedColumn))")
        return ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "table")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Select Column to Analyze")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose the column containing the text you want to analyze for sentiment.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Column Selection
                VStack(spacing: 16) {
                    Text("Available Columns")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if fileImportViewModel.columns.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(fileImportViewModel.columns, id: \.self) { column in
                                    ColumnSelectionCard(
                                        columnName: column,
                                        isSelected: fileImportViewModel.selectedColumn == column,
                                        onTap: {
                                            fileImportViewModel.selectedColumn = column
                                        }
                                    )
                                    .onAppear {
                                        print("[ColumnSelectionView] Rendering column: \(column), selected: \(String(describing: fileImportViewModel.selectedColumn))")
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .coordinateSpace(name: "scrollView")
                        .frame(height: 112) // Constrain height to card height + padding
                    }
                }
                
                // Data Preview
                VStack(spacing: 12) {
                    HStack {
                        Text("Data Preview")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    if fileImportViewModel.columns.isEmpty || fileImportViewModel.previewData.isEmpty {
                        VStack {
                            Image(systemName: "tablecells")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("No data available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 100)
                    } else {
                        VStack(spacing: 8) {
                            if let selectedColumn = fileImportViewModel.selectedColumn {
                                Text("Preview of '\(selectedColumn)' column:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                previewTable(selectedColumn: selectedColumn)
                            } else {
                                Text("Select a column to see a preview of its data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: 150)
                    }
                }
                
                // Navigation Buttons
                VStack(spacing: 16) {
                    Button("Start Analysis") {
                        Task { @MainActor in
                            await analysisViewModel.reset()
                            analysisViewModel.startAnalysis(
                                fileImportViewModel: fileImportViewModel,
                                model: selectedModel,
                                additionalContext: additionalContext
                            )
                            appFlowViewModel.goToNextStep()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fileImportViewModel.selectedColumn == nil)
                    .controlSize(.large)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ColumnSelectionCard: View {
    let columnName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(columnName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .frame(width: 120, height: 80)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let fileImportVM = FileImportViewModel()
    fileImportVM.columns = ["Review", "User", "Date"]
    fileImportVM.previewData = [
        ["Great product!", "Alice", "2024-06-01"],
        ["Not what I expected.", "Bob", "2024-06-02"],
        ["Would buy again.", "Charlie", "2024-06-03"]
    ]
    fileImportVM.selectedColumn = "Review"
    return ColumnSelectionView(
        appFlowViewModel: AppFlowViewModel(),
        fileImportViewModel: fileImportVM,
        analysisViewModel: AnalysisViewModel(),
        selectedModel: "gemma3:1b",
        additionalContext: "Analyze the sentiment of the text in the selected column."
    )
} 