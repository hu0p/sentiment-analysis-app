import Foundation
import Combine

struct SentimentResult: Identifiable {
    let id = UUID()
    let original: String
    var sentiment: String
}

class AnalysisViewModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var isComplete: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String? = nil
    @Published var results: [SentimentResult] = []
    @Published var currentModel: String = ""
    @Published var currentFileName: String = ""
    
    private var comments: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var task: Task<Void, Never>? = nil
    
    func startAnalysis(fileImportViewModel: FileImportViewModel, model: String) {
        reset()
        currentModel = model
        if let fileURL = fileImportViewModel.fileURL {
            currentFileName = fileURL.lastPathComponent
        } else {
            currentFileName = ""
        }
        isAnalyzing = true
        statusMessage = "Extracting data..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let comments = fileImportViewModel.getDataForSelectedColumn()
            
            DispatchQueue.main.async {
                self.comments = comments
                self.statusMessage = "Analyzing \(comments.count) comments..."
                self.runAnalysis(model: model)
            }
        }
    }
    
    private func runAnalysis(model: String) {
        guard !comments.isEmpty else {
            self.statusMessage = "No comments to analyze."
            self.isAnalyzing = false
            self.isComplete = true
            return
        }
        results = []
        progress = 0.0
        isComplete = false
        hasError = false
        errorMessage = nil
        let total = comments.count
        task = Task {
            for (idx, comment) in comments.enumerated() {
                if Task.isCancelled { break }
                let sentiment = await self.analyzeSentiment(comment: comment, model: model)
                if Task.isCancelled { break }
                await MainActor.run {
                    self.results.append(SentimentResult(original: comment, sentiment: sentiment))
                    self.progress = Double(idx + 1) / Double(total)
                    self.statusMessage = "Analyzed \(idx + 1) of \(total) comments..."
                }
            }
            await MainActor.run {
                if Task.isCancelled {
                    self.isAnalyzing = false
                    self.isComplete = false
                    self.statusMessage = "Analysis aborted."
                } else {
                    self.isAnalyzing = false
                    self.isComplete = true
                    self.statusMessage = "Analysis complete!"
                }
            }
        }
    }
    
    private func analyzeSentiment(comment: String, model: String) async -> String {
        // Call Ollama API (assume localhost:11434, model from parameter)
        guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "neutral" }
        let prompt = """
You are analyzing feedback. Respond with ONLY one word: positive, negative, mixed, or neutral.\nComment: \"\(comment)\"\nSentiment:
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
    
    func reset() {
        progress = 0.0
        statusMessage = ""
        isAnalyzing = false
        isComplete = false
        hasError = false
        errorMessage = nil
        results = []
        currentModel = ""
        currentFileName = ""
        comments = []
        task?.cancel()
        task = nil
    }
} 
