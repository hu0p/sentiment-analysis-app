import SwiftUI
import UniformTypeIdentifiers

@main
struct SentimentAnalysisApp: App {
    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .frame(minWidth: 600, minHeight: 725)
        }
    }
}

struct AppFlowView: View {
    @StateObject private var viewModel = AppFlowViewModel()
    @StateObject private var ollamaManager = OllamaManager()
    @StateObject private var fileImportViewModel = FileImportViewModel()
    @StateObject private var analysisViewModel = AnalysisViewModel()
    @State private var selectedModel: String = ""
    
    var body: some View {
        VStack {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(onContinue: { viewModel.goToNextStep() })
            case .ollamaSetup:
                OllamaSetupView(ollamaManager: ollamaManager, onContinue: { viewModel.goToNextStep() })
            case .modelSelection:
                ModelSelectionView(ollamaManager: ollamaManager, selectedModel: $selectedModel, onContinue: { viewModel.goToNextStep() })
            case .fileImport:
                FileImportView(viewModel: fileImportViewModel, onContinue: {
                    if fileImportViewModel.selectedColumn != nil {
                        analysisViewModel.startAnalysis(fileImportViewModel: fileImportViewModel, model: selectedModel)
                        viewModel.goToNextStep()
                    }
                })
            case .analysisProgress:
                AnalysisProgressView(viewModel: analysisViewModel, onContinue: { viewModel.goToNextStep() })
            case .resultsSummary:
                ResultsSummaryView(
                    results: analysisViewModel.results,
                    onExport: exportResults,
                    onStartOver: resetAll
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Kill ollama server on app exit
            ollamaManager.stopOllamaServer()
        }
    }
    
    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "sentiment_results.csv"
        if panel.runModal() == .OK, let url = panel.url {
            let csv = analysisViewModel.results.reduce("Comment,Sentiment\n") { acc, result in
                let comment = result.original.replacingOccurrences(of: "\"", with: "\"\"")
                return acc + "\"\(comment)\",\(result.sentiment)\n"
            }
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func resetAll() {
        viewModel.resetFlow()
        fileImportViewModel.reset()
        analysisViewModel.reset()
    }
} 
