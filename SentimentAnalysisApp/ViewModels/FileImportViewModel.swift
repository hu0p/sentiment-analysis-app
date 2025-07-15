import Foundation
import SwiftUI
import CoreXLSX

class FileImportViewModel: ObservableObject {
    @Published var fileURL: URL? = nil {
        didSet {
            if let url = fileURL {
                UserDefaults.standard.set(url.path, forKey: "selectedFilePath")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedFilePath")
            }
        }
    }
    @Published var columns: [String] = []
    @Published var selectedColumn: String? = nil {
        didSet {
            if let col = selectedColumn {
                UserDefaults.standard.set(col, forKey: "selectedColumn")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedColumn")
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var previewData: [[String]] = []
    
    // Store file parsing info for later data extraction
    private var xlsxFile: XLSXFile?
    private var sharedStrings: SharedStrings?
    private var worksheet: Worksheet?
    
    init() {
        // Restore fileURL if file exists
        if let savedPath = UserDefaults.standard.string(forKey: "selectedFilePath") {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                self.fileURL = url
                // Automatically import the file to populate columns and preview
                self.importFile(url: url)
            }
        }
    }
    
    func importFile(url: URL) {
        self.fileURL = url
        self.isLoading = true
        self.errorMessage = nil
        self.columns = []
        self.selectedColumn = nil
        self.previewData = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (columns, previewData) = try self.parseFileHeaders(url: url)
                DispatchQueue.main.async {
                    self.columns = columns
                    self.previewData = previewData
                    // Only restore selectedColumn if file path matches UserDefaults
                    if let savedPath = UserDefaults.standard.string(forKey: "selectedFilePath"),
                       savedPath == url.path,
                       let savedCol = UserDefaults.standard.string(forKey: "selectedColumn"),
                       columns.contains(savedCol) {
                        self.selectedColumn = savedCol
                    } else if columns.count == 1 {
                        self.selectedColumn = columns.first
                    }
                    self.isLoading = false
                }
            } catch {
                // Handle error silently for distribution
            }
        }
    }
    
    func getDataForSelectedColumn() -> [String] {
        guard let selectedColumn = selectedColumn,
              let columnIndex = columns.firstIndex(of: selectedColumn) else {
            return []
        }
        
        do {
            return try extractColumnData(columnIndex: columnIndex)
        } catch {
            return []
        }
    }
    
    private func parseFileHeaders(url: URL) throws -> ([String], [[String]]) {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "csv":
            return try parseCSVHeaders(url: url)
        case "xlsx":
            return try parseXLSXHeaders(url: url)
        default:
            throw NSError(domain: "FileImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unsupported file format. Please use CSV or XLSX files."])
        }
    }
    
    private func parseCSVHeaders(url: URL) throws -> ([String], [[String]]) {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FileImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file as UTF-8 text."])
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw NSError(domain: "FileImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "File is empty."])
        }
        
        // Parse first few lines for preview
        var previewData: [[String]] = []
        for line in lines.prefix(5) {
            let columns = parseCSVLine(line)
            previewData.append(columns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        
        // Use first row as headers
        let columns = previewData.first ?? []
        
        return (columns, previewData)
    }
    
    private func parseXLSXHeaders(url: URL) throws -> ([String], [[String]]) {
        guard let xlsx = XLSXFile(filepath: url.path) else {
            throw NSError(domain: "FileImport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not open XLSX file."])
        }
        
        // Store for later data extraction
        self.xlsxFile = xlsx
        
        // Get the first worksheet
        let worksheet = try xlsx.parseWorksheet(at: "xl/worksheets/sheet1.xml")
        self.worksheet = worksheet
        
        // Get shared strings for text values
        let sharedStrings = try xlsx.parseSharedStrings()
        self.sharedStrings = sharedStrings
        
        // Get the first 5 rows for preview
        let rows = worksheet.data?.rows.prefix(5) ?? []
        var previewData: [[String]] = []
        
        for row in rows {
            let sortedCells = row.cells.sorted(by: { $0.reference.column < $1.reference.column })
            let rowData = sortedCells.map { getCellValue(cell: $0, sharedStrings: sharedStrings) }
            previewData.append(rowData)
        }
        
        // Use first row as headers
        let columns = previewData.first ?? []
        
        return (columns, previewData)
    }
    
    private func extractColumnData(columnIndex: Int) throws -> [String] {
        guard let fileURL = fileURL else {
            return []
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        case "csv":
            return try extractCSVColumnData(columnIndex: columnIndex)
        case "xlsx":
            return try extractXLSXColumnData(columnIndex: columnIndex)
        default:
            return []
        }
    }
    
    private func extractCSVColumnData(columnIndex: Int) throws -> [String] {
        let data = try Data(contentsOf: fileURL!)
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FileImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file as UTF-8 text."])
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            return [] // Only header row, no data
        }
        
        var columnData: [String] = []
        
        // Skip the header row, start from line 2
        for line in lines.dropFirst() {
            let columns = parseCSVLine(line)
            if columnIndex < columns.count {
                let cellValue = columns[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !cellValue.isEmpty {
                    columnData.append(cellValue)
                }
            }
        }
        
        return columnData
    }
    
    private func extractXLSXColumnData(columnIndex: Int) throws -> [String] {
        guard let worksheet = worksheet,
              let sharedStrings = sharedStrings else {
            return []
        }
        
        var columnData: [String] = []
        
        // Skip the header row, start from row 2
        let dataRows = worksheet.data?.rows.dropFirst() ?? []
        
        for row in dataRows {
            let sortedCells = row.cells.sorted(by: { $0.reference.column < $1.reference.column })
            if columnIndex < sortedCells.count {
                let cellValue = getCellValue(cell: sortedCells[columnIndex], sharedStrings: sharedStrings)
                if !cellValue.isEmpty {
                    columnData.append(cellValue)
                }
            }
        }
        
        return columnData
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in line {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if !insideQuotes {
                    columns.append(currentColumn)
                    currentColumn = ""
                } else {
                    currentColumn.append(char)
                }
            default:
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn)
        return columns
    }
    
    private func getCellValue(cell: CoreXLSX.Cell, sharedStrings: SharedStrings?) -> String {
        // First try to get the string value using shared strings
        if let sharedStrings = sharedStrings,
           let stringValue = cell.stringValue(sharedStrings) {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If no shared string value, try the direct value
        if let value = cell.value {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If cell is empty, return empty string
        return ""
    }
    
    func removeFile() {
        fileURL = nil
        columns = []
        selectedColumn = nil
        isLoading = false
        errorMessage = nil
        previewData = []
        
        // Clear XLSX-specific properties to prevent old file references
        xlsxFile = nil
        sharedStrings = nil
        worksheet = nil
    }
    
    func reset() {
        fileURL = nil
        columns = []
        selectedColumn = nil
        isLoading = false
        errorMessage = nil
        previewData = []
        
        // Clear XLSX-specific properties to prevent old file references
        xlsxFile = nil
        sharedStrings = nil
        worksheet = nil
    }
} 