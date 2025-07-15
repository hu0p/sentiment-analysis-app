# SwiftUI macOS Sentiment Analysis App — Planning & Structure

## Project Structure

```
SentimentAnalysisApp/
├── AppDelegate.swift
├── SentimentAnalysisApp.swift         # Main SwiftUI app entry
├── Models/
│   ├── SentimentResult.swift         # Data model for analysis results
│   └── FileColumn.swift              # Model for representing file columns
├── Views/
│   ├── WelcomeView.swift             # Step 1: Welcome & prerequisites
│   ├── OllamaSetupView.swift         # Step 2: Ollama install/check/model download
│   ├── FileImportView.swift          # Step 3: File picker & column selection
│   ├── AnalysisProgressView.swift    # Step 4: Analysis progress/status
│   ├── ResultsSummaryView.swift      # Step 5: Results summary & export/start over
│   └── ErrorView.swift               # Error handling
├── ViewModels/
│   ├── AppFlowViewModel.swift        # Controls step navigation and state
│   ├── OllamaManager.swift           # Handles Ollama install/check/model download
│   ├── FileImportViewModel.swift     # Handles file parsing and column selection
│   ├── AnalysisViewModel.swift       # Handles sentiment analysis logic
│   └── ExportViewModel.swift         # Handles exporting results
├── Resources/
│   └── Assets.xcassets
├── Utilities/
│   ├── CSVParser.swift               # CSV parsing helpers
│   ├── ExcelParser.swift             # Excel parsing helpers
│   └── Shell.swift                   # Run shell commands/processes
└── Info.plist
```

---

## Step-by-Step Implementation Plan

### 1. **Project Setup**

- Create a new SwiftUI macOS app project in Xcode.
- Set up folders for Models, Views, ViewModels, Utilities, and Resources.

### 2. **Ollama Installation & Model Download**

- Implement `OllamaManager`:
  - Check if `ollama` is installed (using `which ollama`).
  - If not, prompt user and run the install script.
  - Check if `gemma3:4b` is available; if not, run `ollama pull gemma3:4b`.
  - Show progress/status in `OllamaSetupView`.

### 3. **Multi-Step User Flow (AppFlowViewModel)**

- Implement a state machine or enum to represent each step:
  1. Welcome
  2. Initializing Ollama
  3. File Import & Column Selection
  4. Analysis Progress
  5. Results Summary/Export
- Use a single parent view to switch between steps based on state.

### 4. **File Import & Column Selection**

- Use `FileImporter` to let user pick a CSV or Excel file.
- Parse the file (CSVParser/ExcelParser).
- If only one column, use it; otherwise, present a list of columns for user to select.
- Store selected column in `FileImportViewModel`.

### 5. **Sentiment Analysis**

- For each comment, send a request to Ollama API (`/api/generate`).
- Use async/await or Combine for sequential processing and progress updates.
- Show progress bar and current status in `AnalysisProgressView`.
- Store results in `SentimentResult` model.

### 6. **Results Summary & Export**

- Display summary statistics (counts/percentages for each sentiment) in `ResultsSummaryView`.
- Show a preview of the analyzed data.
- Allow user to export results to CSV or Excel (using `ExportViewModel`).
- Provide a "Start Over" button to reset the flow and analyze another file.

### 7. **Error Handling**

- Implement `ErrorView` for user-friendly error messages and recovery options.

### 8. **Polish & Testing**

- Add icons, polish UI, and test the full flow.
- Ensure all edge cases (missing Ollama, file errors, API errors) are handled gracefully.

---

## **User Flow Summary**

1. **Welcome** → 2. **Initializing Ollama** → 3. **File Import/Column Selection** → 4. **Analysis Progress** → 5. **Results/Export/Start Over**
