import SwiftUI
import UniformTypeIdentifiers

@main
struct SentimentAnalysisApp: App {
    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .frame(minWidth: 600, minHeight: 800)
        }
    }
}

struct BackHeaderView: View {
    let onBack: () -> Void
    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

struct AppFlowView: View {
    @StateObject private var viewModel = AppFlowViewModel()
    @StateObject private var ollamaManager = OllamaManager()
    @StateObject private var fileImportViewModel = FileImportViewModel()
    @StateObject private var analysisViewModel = AnalysisViewModel()
    

    @State private var selectedModel: String = ""
    @State private var additionalContext: String = ""
    @State private var isCheckingOllama = false
    @State private var shouldShowOllamaSetup = false
    @State private var ollamaCheckPerformed = false
    
    private let steps: [StepIndicatorView.Step] = [
        .init(title: "Welcome", icon: "hand.wave"),
        .init(title: "Model", icon: "cpu"),
        .init(title: "File", icon: "doc.text"),
        .init(title: "Column", icon: "table"),
        .init(title: "Analyze", icon: "brain.head.profile"),
        .init(title: "Results", icon: "chart.bar.xaxis")
    ]
    
    private func stepIndex(for step: AppFlowViewModel.Step) -> Int {
        switch step {
        case .welcome: return 0
        case .ollamaSetup: return -1 // Ollama step is not in the indicator
        case .modelSelection: return 1
        case .fileImport: return 2
        case .columnSelection: return 3
        case .analysisProgress: return 4
        case .resultsSummary: return 5
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with consistent height
            VStack(spacing: 0) {
                // Show back header only on steps where back is allowed
                if viewModel.currentStep == .modelSelection || viewModel.currentStep == .fileImport || viewModel.currentStep == .columnSelection {
                    BackHeaderView(onBack: { viewModel.goToPreviousStep() })
                }
                // Main step content
                ZStack {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView(onContinue: {
                            if !ollamaCheckPerformed {
                                isCheckingOllama = true
                                ollamaManager.startSetup()
                                DispatchQueue.global(qos: .userInitiated).async {
                                    while !ollamaManager.isReady && !ollamaManager.hasError {
                                        usleep(100_000)
                                    }
                                    DispatchQueue.main.async {
                                        isCheckingOllama = false
                                        ollamaCheckPerformed = true
                                        if ollamaManager.isReady {
                                            viewModel.currentStep = .modelSelection
                                        } else {
                                            shouldShowOllamaSetup = true
                                            viewModel.currentStep = .ollamaSetup
                                        }
                                    }
                                }
                            } else {
                                viewModel.currentStep = .modelSelection
                            }
                        })
                    case .ollamaSetup:
                        if shouldShowOllamaSetup {
                            OllamaSetupView(ollamaManager: ollamaManager, onContinue: {
                                shouldShowOllamaSetup = false
                                viewModel.currentStep = .modelSelection
                            })
                        }
                    case .modelSelection:
                        ModelSelectionView(
                            ollamaManager: ollamaManager,
                            selectedModel: $selectedModel,
                            additionalContext: $additionalContext,
                            onContinue: { viewModel.goToNextStep() }
                        )
                    case .fileImport:
                        FileImportView(
                            viewModel: fileImportViewModel,
                            onContinue: {
                                viewModel.goToNextStep()
                            }
                        )
                    case .columnSelection:
                        ColumnSelectionView(
                            appFlowViewModel: viewModel,
                            fileImportViewModel: fileImportViewModel,
                            analysisViewModel: analysisViewModel
                        )
                    case .analysisProgress:
                        AnalysisProgressView(
                            viewModel: analysisViewModel,
                            onContinue: { viewModel.goToNextStep() },
                            onCancel: {
                                analysisViewModel.reset()
                                viewModel.currentStep = .columnSelection
                            }
                        )
                        .onAppear {
                            if analysisViewModel.results.isEmpty {
                                analysisViewModel.startAnalysis(fileImportViewModel: fileImportViewModel, model: selectedModel, additionalContext: additionalContext)
                            }
                        }
                    case .resultsSummary:
                        ResultsSummaryView(
                            results: $analysisViewModel.results,
                            onExport: exportResults,
                            onStartOver: resetAll
                        )
                    }
                    if isCheckingOllama {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Checking Ollama setup...")
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                            .frame(maxWidth: 300)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fixed footer - Step indicator
            StepIndicatorView(
                steps: steps,
                currentStep: stepIndex(for: viewModel.currentStep),
                showEditIcon: viewModel.currentStep != .modelSelection,
                editIconStepIndex: 1, // Model step is always at index 1
                onEditModel: { viewModel.currentStep = .modelSelection },
                onWelcomeTap: { viewModel.currentStep = .welcome },
                isWelcomeDisabled: viewModel.currentStep == .analysisProgress,
                onModelTap: { 
                    if !ollamaCheckPerformed {
                        isCheckingOllama = true
                        ollamaManager.startSetup()
                        DispatchQueue.global(qos: .userInitiated).async {
                            while !ollamaManager.isReady && !ollamaManager.hasError {
                                usleep(100_000)
                            }
                            DispatchQueue.main.async {
                                isCheckingOllama = false
                                ollamaCheckPerformed = true
                                if ollamaManager.isReady {
                                    viewModel.currentStep = .modelSelection
                                } else {
                                    shouldShowOllamaSetup = true
                                    viewModel.currentStep = .ollamaSetup
                                }
                            }
                        }
                    } else {
                        viewModel.currentStep = .modelSelection
                    }
                },
                isModelSelectionActive: viewModel.currentStep == .modelSelection,
                onFileTap: { 
                    if !fileImportViewModel.columns.isEmpty {
                        viewModel.currentStep = .fileImport
                    }
                },
                isFileStepClickable: !fileImportViewModel.columns.isEmpty,
                onColumnTap: { 
                    if !fileImportViewModel.columns.isEmpty && fileImportViewModel.selectedColumn != nil {
                        viewModel.currentStep = .columnSelection
                    }
                },
                isColumnStepClickable: !fileImportViewModel.columns.isEmpty && fileImportViewModel.selectedColumn != nil,
                onResultsTap: { 
                    if !analysisViewModel.results.isEmpty && analysisViewModel.isComplete {
                        viewModel.currentStep = .resultsSummary
                    }
                },
                isResultsStepClickable: !analysisViewModel.results.isEmpty && analysisViewModel.isComplete,
                isAnalysisInProgress: analysisViewModel.isAnalyzing
            )
            .padding(.top, 8)
            .padding(.bottom, 16)
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
        selectedModel = ""
        additionalContext = ""
    }
} 
