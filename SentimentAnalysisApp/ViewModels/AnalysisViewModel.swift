import Foundation
import Combine

struct SentimentResult: Identifiable {
    let id = UUID()
    let original: String
    var sentiment: String
}

// Actor to manage the analysis task, ensuring only one runs at a time
actor AnalysisTaskManager {
    private var currentTask: Task<Void, Never>? = nil

    func startAnalysis(work: @escaping () async -> Void) async {
        currentTask?.cancel()
        await currentTask?.value // Wait for the old task to finish
        currentTask = Task {
            await work()
        }
    }

    func cancel() async {
        currentTask?.cancel()
        await currentTask?.value
        currentTask = nil
    }
}

class AnalysisViewModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var isComplete: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String? = nil
    @Published var results: [SentimentResult] = []
    @Published var currentModel: String = "" {
        didSet {
            // Persist to UserDefaults when changed
            UserDefaults.standard.set(currentModel, forKey: "selectedModel")
        }
    }
    @Published var currentFileName: String = ""
    @Published var runID: UUID = UUID()
    
    private var comments: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var task: Task<Void, Never>? = nil
    private var isCancelling: Bool = false
    private let taskManager = AnalysisTaskManager()
    
    init() {
        // Restore model from UserDefaults if present
        let savedModel = UserDefaults.standard.string(forKey: "selectedModel")
        print("[AnalysisViewModel] Restoring selectedModel from UserDefaults: \(String(describing: savedModel))")
        if let savedModel = savedModel {
            self.currentModel = savedModel
        }
    }
    
    func startAnalysis(fileImportViewModel: FileImportViewModel, model: String, additionalContext: String = "") {
        statusMessage = ""
        print("[AnalysisViewModel] startAnalysis called (actor-based).")
        currentModel = model
        if let fileURL = fileImportViewModel.fileURL {
            currentFileName = fileURL.lastPathComponent
        } else {
            currentFileName = ""
        }
        isAnalyzing = true
        statusMessage = "Extracting data..."
        let comments = fileImportViewModel.getDataForSelectedColumn()
        print("[AnalysisViewModel] Extracted \(comments.count) comments from selected column.")
        self.comments = comments
        self.statusMessage = "Analyzing \(comments.count) comments..."
        Task {
            await taskManager.startAnalysis {
                await self.runAnalysis(model: model, additionalContext: additionalContext)
            }
        }
    }

    func abortAnalysis() {
        Task {
            await taskManager.cancel()
        }
    }

    func runAnalysis(model: String, additionalContext: String) async {
        print("[AnalysisViewModel] runAnalysis called (actor-based). comments.count: \(comments.count)")
        guard !comments.isEmpty else {
            await MainActor.run {
                self.statusMessage = "No comments to analyze."
                self.isAnalyzing = false
                self.isComplete = true
                print("[AnalysisViewModel] No comments to analyze. Exiting runAnalysis.")
            }
            return
        }
        await MainActor.run {
            self.results = []
            self.progress = 0.0
            self.isComplete = false
            self.hasError = false
            self.errorMessage = nil
        }
        let total = comments.count
        for (idx, comment) in comments.enumerated() {
            if Task.isCancelled {
                print("[AnalysisViewModel] Task cancelled in loop at idx: \(idx)")
                break
            }
            let sentiment = await self.analyzeSentiment(comment: comment, model: model, additionalContext: additionalContext)
            if Task.isCancelled {
                print("[AnalysisViewModel] Task cancelled after analyzeSentiment at idx: \(idx)")
                break
            }
            await MainActor.run {
                self.results.append(SentimentResult(original: comment, sentiment: sentiment))
                self.progress = Double(idx + 1) / Double(total)
                self.statusMessage = "Analyzing \(idx + 1) of \(total) comments..."
            }
        }
        await MainActor.run {
            if Task.isCancelled {
                self.isAnalyzing = false
                self.isComplete = false
                print("[AnalysisViewModel] Task finished as cancelled.")
            } else {
                self.isAnalyzing = false
                self.isComplete = true
                self.statusMessage = "Analysis complete!"
                print("[AnalysisViewModel] Task finished as complete.")
            }
        }
    }
    
    private func analyzeSentiment(comment: String, model: String, additionalContext: String) async -> String {
        // Call Ollama API (assume localhost:11434, model from parameter)
        guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "neutral" }
        
        let contextString = additionalContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " \(additionalContext)"
        let prompt = """
You are analyzing text sentiment.\(contextString) Respond with ONLY one word: positive, negative, mixed, or neutral.\nComment: \"\(comment)\"\nSentiment:
"""
        let url = URL(string: "http://localhost:11434/api/generate")!
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (responseData, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let response = json["response"] as? String {
                let resp = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if resp.contains("positive") { return "positive" }
                if resp.contains("negative") { return "negative" }
                if resp.contains("mixed") { return "mixed" }
                if resp.contains("neutral") { return "neutral" }
            }
        } catch {
            // Ignore error, treat as neutral
        }
        return "neutral"
    }
    
    @MainActor
    func reset() async {
        print("[AnalysisViewModel] async reset called (actor-based).")
        isCancelling = true
        await taskManager.cancel()
        statusMessage = ""
        progress = 0.0
        isAnalyzing = false
        isComplete = false
        hasError = false
        errorMessage = nil
        results = []
        currentModel = ""
        currentFileName = ""
        comments = []
        isCancelling = false
        runID = UUID()
        print("[AnalysisViewModel] async reset finished (actor-based).")
    }
} 
