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
    @Published var installLog: [String] = []
    @Published var shouldPromptForBrewInstall: Bool = false
    @Published var isWaitingForManualInstall: Bool = false
    
    private var detectedBrewPath: String? = nil
    private var isInstallingManually: Bool = false
    
    private let baseURL = "http://localhost:11434"
    private let modelName = "gemma3:1b"
    
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
        print("[OllamaManager] startSetup called")
        progress = 0.0
        isReady = false
        hasError = false
        // Don't reset isInstallingManually here - only reset it when we're done
        statusMessage = "Checking for Ollama installation..."
        DispatchQueue.global(qos: .userInitiated).async {
                      // Check if Ollama is already installed before fallback
            if let ollamaPath = self.isOllamaInstalled() {
                print("[OllamaManager] Ollama already installed at \(ollamaPath). Skipping fallback install.")
                self.continueSetupAfterInstall(ollamaPath: ollamaPath)
                return
            }


            var brewPath = ""
            // Try 'which brew' first
            let whichBrew = Process()
            whichBrew.launchPath = "/usr/bin/which"
            whichBrew.arguments = ["brew"]
            let brewPipe = Pipe()
            whichBrew.standardOutput = brewPipe
            whichBrew.standardError = brewPipe
            do {
                try whichBrew.run()
                whichBrew.waitUntilExit()
                let brewData = brewPipe.fileHandleForReading.readDataToEndOfFile()
                brewPath = String(data: brewData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } catch {
                // Ignore error, will check common paths below
            }
            // If not found, check common Homebrew locations
            if brewPath.isEmpty {
                let possibleBrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
                for path in possibleBrewPaths {
                    if FileManager.default.fileExists(atPath: path) {
                        brewPath = path
                        break
                    }
                }
            }
            print("[OllamaManager] Detected brew path: \(brewPath)")
            if && !brewPath.isEmpty {
                DispatchQueue.main.async {
                    self.statusMessage = "Brew environment detected!"
                    self.shouldPromptForBrewInstall = true
                    self.detectedBrewPath = brewPath
                }
                // Pause setup until user confirms in UI
                return
            }
            // If no brew, try normal install flow
            print("[OllamaManager] No brew detected, calling installOllamaWithFallback")
            self.installOllamaWithFallback()
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
        
        // First check if Ollama.app exists in Applications
        let ollamaAppPath = "/Applications/Ollama.app"
        if fileManager.fileExists(atPath: ollamaAppPath) {
            let binaryPath = "\(ollamaAppPath)/Contents/MacOS/ollama"
            if fileManager.fileExists(atPath: binaryPath) {
                let process = Process()
                process.launchPath = binaryPath
                process.arguments = ["--version"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    print("[OllamaManager] Ran ollama at \(binaryPath), exit: \(process.terminationStatus), output: \(output)")
                    if process.terminationStatus == 0 {
                        return binaryPath
                    }
                } catch {
                    print("[OllamaManager] Failed to run ollama at \(binaryPath): \(error)")
                }
            }
        }
        
        // Then check other known paths
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
    

    
    // Fallback install logic (pkg)
    private func installOllamaWithFallback() {
        print("[OllamaManager] installOllamaWithFallback called. isInstallingManually: \(isInstallingManually)")
        
        // Prevent duplicate installation attempts
        guard !isInstallingManually else {
            print("[OllamaManager] Manual installation already in progress, skipping duplicate attempt")
            return
        }
        
        isInstallingManually = true
        print("[OllamaManager] Set isInstallingManually = true")
        DispatchQueue.main.async {
            self.installLog = []
        }
        let dmgURLString = "https://www.ollama.com/download/Ollama.dmg"
        guard let dmgURL = URL(string: dmgURLString) else {
            let errorMsg = "[OllamaManager] Invalid Ollama .dmg URL."
            DispatchQueue.main.async {
                self.installLog = [errorMsg]
            }
            print(errorMsg)
            self.updateError("Ollama could not be installed automatically. Please install it manually.")
            return
        }
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let tempDmgPath = tempDir.appendingPathComponent("Ollama.dmg").path
        let downloadSemaphore = DispatchSemaphore(value: 0)
        var downloadSuccess = false
        var downloadError: String? = nil
        var httpStatus: Int = 0
        var contentType: String = ""
        var fileSize: UInt64 = 0
        var request = URLRequest(url: dmgURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.downloadTask(with: request) { location, response, error in
            defer { downloadSemaphore.signal() }
            if let httpResponse = response as? HTTPURLResponse {
                httpStatus = httpResponse.statusCode
                contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            }
            if let error = error {
                let msg = "[OllamaManager] Failed to download .dmg: \(error)"
                DispatchQueue.main.async {
                    self.installLog = [msg]
                }
                downloadError = msg
                return
            }
            guard let location = location else {
                let msg = "[OllamaManager] No file location for .dmg download."
                DispatchQueue.main.async {
                    self.installLog = [msg]
                }
                downloadError = msg
                return
            }
            do {
                if fileManager.fileExists(atPath: tempDmgPath) {
                    try fileManager.removeItem(atPath: tempDmgPath)
                }
                try fileManager.moveItem(at: location, to: URL(fileURLWithPath: tempDmgPath))
                let attrs = try fileManager.attributesOfItem(atPath: tempDmgPath)
                fileSize = (attrs[.size] as? UInt64) ?? 0
                downloadSuccess = true
            } catch {
                let msg = "[OllamaManager] Error moving .dmg: \(error)"
                DispatchQueue.main.async {
                    self.installLog = [msg]
                }
                downloadError = msg
            }
        }
        task.resume()
        downloadSemaphore.wait()
        print("[OllamaManager] HTTP status: \(httpStatus)")
        print("[OllamaManager] Content-Type: \(contentType)")
        print("[OllamaManager] Downloaded file size: \(fileSize) bytes")
        if !downloadSuccess || httpStatus != 200 || fileSize < 1024 * 1024 {
            let errorMsg = downloadError ?? "[OllamaManager] Downloaded .dmg is invalid or too small (\(fileSize) bytes)."
            DispatchQueue.main.async {
                self.installLog = [errorMsg]
            }
            print(errorMsg)
            self.updateError("Ollama could not be installed automatically. Please install it manually.")
            return
        }
        // Open the .dmg in Finder from temp directory
        let openProcess = Process()
        openProcess.launchPath = "/usr/bin/open"
        openProcess.arguments = [tempDmgPath]
        do {
            try openProcess.run()
            openProcess.waitUntilExit()
            let msg = "[OllamaManager] Opened .dmg in Finder. Please install manually if not prompted."
            DispatchQueue.main.async {
                self.installLog.append(msg)
                self.isWaitingForManualInstall = true
                self.updateStatus("Waiting for Ollama installation...")
            }
            print(msg)
            // Show waiting status and poll for install
            DispatchQueue.global(qos: .userInitiated).async {
                let maxWait: TimeInterval = 600 // 10 minutes
                let pollInterval: TimeInterval = 2
                let start = Date()
                while Date().timeIntervalSince(start) < maxWait {
                    if let ollamaPath = self.isOllamaInstalled() {
                        DispatchQueue.main.async {
                            self.isWaitingForManualInstall = false
                        }
                        self.continueSetupAfterInstall(ollamaPath: ollamaPath, tempDmgPath: tempDmgPath)
                        return
                    }
                    Thread.sleep(forTimeInterval: pollInterval)
                }
                DispatchQueue.main.async {
                    self.isWaitingForManualInstall = false
                }
                self.isInstallingManually = false
                self.updateError("Ollama was not installed after waiting. Please try again or install manually.")
            }
            return
        } catch {
            let errorMsg = "[OllamaManager] Failed to open .dmg: \(error)"
            DispatchQueue.main.async {
                self.installLog.append(errorMsg)

            }
            print(errorMsg)

            self.isInstallingManually = false
            self.updateError("Ollama could not be installed automatically. Please install it manually.")
            return
        }
        // If still not found, show error
        self.updateError("Ollama could not be installed automatically. Please install it manually.")
    }

    // Continue the rest of the setup after install
    private func continueSetupAfterInstall(ollamaPath: String, tempDmgPath: String? = nil) {
        // Reset installation flag
        self.isInstallingManually = false
        print("[OllamaManager] Reset isInstallingManually = false (success)")
        
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
        self.updateStatus("Ollama is ready! Please select a model.")
        self.setReady()
        // Delete the temp .dmg if provided
        if let tempDmgPath = tempDmgPath {
            do {
                try FileManager.default.removeItem(atPath: tempDmgPath)
                print("[OllamaManager] Deleted temp .dmg at \(tempDmgPath)")
            } catch {
                print("[OllamaManager] Failed to delete temp .dmg: \(error)")
            }
        }
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
            self.isInstallingManually = false
            print("[OllamaManager] Reset isInstallingManually = false (ready)")
        }
    }
    
    private func updateError(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.hasError = true
            self.isReady = false
            self.isInstallingManually = false
            print("[OllamaManager] Reset isInstallingManually = false (error)")
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



    func continueBrewInstall() {
        guard let brewPath = self.detectedBrewPath else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let brewInstall = Process()
            brewInstall.launchPath = brewPath
            brewInstall.arguments = ["install", "ollama"]
            let pipe = Pipe()
            brewInstall.standardOutput = pipe
            brewInstall.standardError = pipe
            do {
                try brewInstall.run()
                brewInstall.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n")
                DispatchQueue.main.async {
                    self.installLog = lines
                }
                print("[OllamaManager] Homebrew install output:\n\(output)")
                if brewInstall.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        self.installLog.append("Ollama installed successfully. Continuing setup...")
                        self.shouldPromptForBrewInstall = false
                    }
                    // After successful install, continue setup
                    if let ollamaPath = self.isOllamaInstalled() {
                        self.continueSetupAfterInstall(ollamaPath: ollamaPath)
                        return
                    }
                } else {
                    let failMsg = "[OllamaManager] Homebrew install failed with exit code \(brewInstall.terminationStatus)"
                    DispatchQueue.main.async {
                        self.installLog.append(failMsg)
                        self.shouldPromptForBrewInstall = false
                    }
                    print(failMsg)
                    // Fallback to .pkg
                    self.installOllamaWithFallback()
                }
            } catch {
                let errorMsg = "[OllamaManager] Error running brew install: \(error)"
                DispatchQueue.main.async {
                    self.installLog.append(errorMsg)
                    self.shouldPromptForBrewInstall = false
                }
                print(errorMsg)
                // Fallback to .pkg
                self.installOllamaWithFallback()
            }
        }
    }
} 