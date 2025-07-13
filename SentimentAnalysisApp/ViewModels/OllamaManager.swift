import Foundation
import Combine

class OllamaManager: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var isReady: Bool = false
    @Published var hasError: Bool = false
    @Published var availableModels: [String] = []
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadOutput: [String] = []
    @Published var downloadModelName: String = ""
    
    private let baseURL = "http://localhost:11434"
    private let modelName = "gemma3:4b"
    
    private func waitForOllamaServerReady(timeout: TimeInterval = 10.0) {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if isOllamaServerRunning() {
                print("[OllamaManager] Ollama server is ready.")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("[OllamaManager] Ollama server did not become ready in time.")
    }

    func startSetup() {
        progress = 0.0
        isReady = false
        hasError = false
        statusMessage = "Checking for Ollama installation..."
        DispatchQueue.global(qos: .userInitiated).async {
            // Only use --version for initial binary check
            guard let ollamaPath = self.isOllamaInstalled() else {
                self.updateError("Ollama not found in known locations. Please install it manually.")
                return
            }
            self.updateStatus("Ollama found at: \(ollamaPath). Starting server...")
            // Start the server if not running
            self.startOllamaServer(ollamaPath: ollamaPath)
            // Wait for the server to be ready
            self.waitForOllamaServerReady()
            self.updateProgress(0.3)
            self.updateStatus("Checking for available models...")
            // Populate available models using API
            _ = self.listAvailableModels()
            self.updateProgress(1.0)
            self.updateStatus("Ollama is ready!")
            self.setReady()
        }
    }
    
    private var cachedUserShellPath: String? = nil

    private func getUserShellPath() -> String? {
        if let cached = cachedUserShellPath { return cached }
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Always prepend Homebrew paths if missing
        let brewPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        for brewPath in brewPaths.reversed() { // reversed so /opt/homebrew/bin is first
            if !path.split(separator: ":").contains(Substring(brewPath)) {
                path = brewPath + ":" + path
            }
        }
        cachedUserShellPath = path
        print("[OllamaManager] User shell PATH (with Homebrew): \(path)")
        return path
    }

    private func canRunOllama(at path: String) -> Bool {
        let process = Process()
        process.launchPath = path
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[OllamaManager] Ran ollama at \(path), exit: \(process.terminationStatus), output: \(output)")
            return process.terminationStatus == 0
        } catch {
            print("[OllamaManager] Failed to run ollama at \(path): \(error)")
            return false
        }
    }

    private let knownOllamaPaths = [
        "/opt/homebrew/bin/ollama",
        "/usr/local/bin/ollama",
        "/usr/bin/ollama",
        "/bin/ollama"
    ]

    func isOllamaInstalled() -> String? {
        let fileManager = FileManager.default
        for path in knownOllamaPaths {
            if fileManager.fileExists(atPath: path) {
                let process = Process()
                process.launchPath = path
                process.arguments = ["--version"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    print("[OllamaManager] Ran ollama at \(path), exit: \(process.terminationStatus), output: \(output)")
                    if process.terminationStatus == 0 {
                        return path
                    }
                } catch {
                    print("[OllamaManager] Failed to run ollama at \(path): \(error)")
                }
            }
        }
        return nil
    }
    
    private func promptUserToGrantAccessToOllama(at path: String, completion: @escaping (String?) -> Void) {
        // This function is no longer needed as access is assumed.
        // Keeping it for now, but it will not be called.
        print("[OllamaManager] promptUserToGrantAccessToOllama called, but access is assumed.")
        completion(path) // Assume granted for now
    }
    
    private func promptUserToSelectOllamaBinary() {
        // TODO: Implement UI to let user select ollama binary if not found automatically
        print("[OllamaManager] Prompting user to select ollama binary (not yet implemented)")
    }
    
    private func installOllama() -> Bool {
        let script = "curl -fsSL https://ollama.com/install.sh | sh"
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
    
    private func isModelAvailable() -> Bool {
        // Use API to check if model is available
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAvailable = false
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                return
            }
            
            for model in models {
                if let name = model["name"] as? String, name == self.modelName {
                    isAvailable = true
                    break
                }
            }
        }.resume()
        
        semaphore.wait()
        return isAvailable
    }
    
    private func pullModel(named modelName: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/pull") else { return false }
        
        let payload: [String: Any] = [
            "name": modelName
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Use URLSession's dataTaskPublisher for streaming
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            // Check HTTP status code first
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[OllamaManager] Invalid response type")
                return false
            }
            
            // If status code indicates error, return false
            if httpResponse.statusCode != 200 {
                print("[OllamaManager] HTTP error: \(httpResponse.statusCode)")
                return false
            }
            
            var hasError = false
            var isCompleted = false
            
            // Process streaming response
            for try await line in asyncBytes.lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else { continue }
                
                // Try to parse each line as JSON
                if let lineData = trimmedLine.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                    
                    // Update status message
                    if let status = json["status"] as? String {
                        await MainActor.run {
                            self.updateStatus(status)
                        }
                    }
                    
                    // Check for error field
                    if let error = json["error"] as? String {
                        print("[OllamaManager] Pull failed with error: \(error)")
                        await MainActor.run {
                            self.updateError(error)
                        }
                        hasError = true
                        break
                    }
                    
                    // Check for completion
                    if let status = json["status"] as? String {
                        if status == "success" {
                            print("[OllamaManager] Pull completed successfully")
                            isCompleted = true
                            break
                        }
                    }
                    
                    // Update progress if available
                    if let completed = json["completed"] as? Int,
                       let total = json["total"] as? Int,
                       total > 0 {
                        let progress = Double(completed) / Double(total)
                        await MainActor.run {
                            self.updateProgress(progress)
                        }
                    }
                    
                    // Update download output for detailed logging
                    await MainActor.run {
                        self.downloadOutput.append(trimmedLine)
                    }
                }
            }
            
            return !hasError && isCompleted
            
        } catch {
            print("[OllamaManager] Error pulling model: \(error)")
            await MainActor.run {
                self.updateError("Network error: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
    
    private func updateProgress(_ value: Double) {
        DispatchQueue.main.async {
            self.progress = min(max(value, 0.0), 1.0)
        }
    }
    
    private func setReady() {
        DispatchQueue.main.async {
            self.isReady = true
            self.hasError = false
            self.progress = 1.0
        }
    }
    
    private func updateError(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.hasError = true
            self.isReady = false
        }
    }

    private var ollamaServerProcess: Process?

    private func isOllamaServerRunning() -> Bool {
        // Try connecting to the default Ollama server port (11434)
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", ":11434"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.contains("LISTEN")
    }

    private func startOllamaServer(ollamaPath: String) {
        if isOllamaServerRunning() {
            print("[OllamaManager] Ollama server already running.")
            return
        }
        let process = Process()
        process.launchPath = ollamaPath
        process.arguments = ["serve"]
        process.standardOutput = nil
        process.standardError = nil
        process.standardInput = nil
        process.qualityOfService = .background
        do {
            try process.run()
            ollamaServerProcess = process
            print("[OllamaManager] Started ollama server.")
            // Give the server a moment to start
            Thread.sleep(forTimeInterval: 2.0)
        } catch {
            print("[OllamaManager] Failed to start ollama server: \(error)")
        }
    }

    func stopOllamaServer() {
        if let process = ollamaServerProcess {
            process.terminate()
            ollamaServerProcess = nil
            print("[OllamaManager] Stopped ollama server.")
        } else {
            // Try to kill any running ollama serve process
            let killTask = Process()
            killTask.launchPath = "/usr/bin/pkill"
            killTask.arguments = ["-f", "ollama serve"]
            try? killTask.run()
            killTask.waitUntilExit()
            print("[OllamaManager] Killed any running ollama serve process.")
        }
    }

    func listAvailableModels() -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        
        let semaphore = DispatchSemaphore(value: 0)
        var models: [String] = []
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsData = json["models"] as? [[String: Any]] else {
                return
            }
            
            models = modelsData.compactMap { model in
                return model["name"] as? String
            }
        }.resume()
        
        semaphore.wait()
        
        DispatchQueue.main.async {
            self.availableModels = models
        }
        print("[OllamaManager] Available models: \(models)")
        return models
    }

    func downloadModel(named modelName: String) {
        Task {
            await MainActor.run {
                self.isDownloading = true
                self.downloadProgress = 0.0
                self.downloadOutput = []
                self.downloadModelName = modelName
                self.updateStatus("Starting download of \(modelName)...")
            }
            
            // Use API to pull model with streaming progress
            let success = await self.pullModel(named: modelName)
            
            await MainActor.run {
                self.isDownloading = false
                
                if success {
                    self.downloadProgress = 1.0
                    self.updateStatus("Model \(modelName) downloaded successfully!")
                    // Refresh available models
                    self.refreshAvailableModels()
                } else {
                    // Error message is already set by pullModel
                    self.downloadProgress = 0.0
                }
            }
        }
    }

    func refreshAvailableModels() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = self.listAvailableModels()
        }
    }

    // Utility to strip ANSI escape codes and control characters
    private func cleanOllamaOutput(_ input: String) -> String {
        // Remove ANSI escape codes
        let ansiRegex = try! NSRegularExpression(pattern: "\\u001B\\[[0-9;]*[A-Za-z]", options: [])
        let range = NSRange(location: 0, length: input.utf16.count)
        var cleaned = ansiRegex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
        // Remove other control characters (except newlines)
        cleaned = cleaned.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0 == "\n") }
        return cleaned
    }

    // Try to extract a progress percentage from a line
    private func extractProgressPercent(from line: String) -> Double? {
        // Example: "pulling  23% complete"
        let percentRegex = try! NSRegularExpression(pattern: "([0-9]{1,3})%", options: [])
        let range = NSRange(location: 0, length: line.utf16.count)
        if let match = percentRegex.firstMatch(in: line, options: [], range: range),
           let percentRange = Range(match.range(at: 1), in: line) {
            let percentString = String(line[percentRange])
            if let percent = Double(percentString) {
                return percent / 100.0
            }
        }
        return nil
    }
} 