import SwiftUI
#if os(macOS)
import AppKit
#endif

struct OllamaSetupView: View {
    @ObservedObject var ollamaManager: OllamaManager
    var onContinue: () -> Void
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    @State private var modelsLoaded: Bool = false
    @State private var showDownloadField: Bool = false
    @State private var newModelName: String = ""
    @State private var modelSelectionMode: String? = nil // "existing" or "download"

    var body: some View {
        VStack {
            VStack(spacing: 24) {
                Image("ollama-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                Text("Initializing Ollama")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Making sure Ollama is installed...")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                ProgressView(value: ollamaManager.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                Text(ollamaManager.statusMessage)
                    .font(.body)
                    .foregroundColor(ollamaManager.hasError ? .red : .primary)
                    .padding(.horizontal)
                if ollamaManager.hasError {
                    Button("Retry") {
                        ollamaManager.startSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .onHover { hovering in
                        #if os(macOS)
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                        #endif
                    }
                    .padding(.top)
                }
            }
            .frame(maxWidth: 600)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ollamaManager.startSetup()
            // availableModels will update automatically via @Published
            if let first = ollamaManager.availableModels.first {
                selectedModel = first
            }
        }
        .onChange(of: ollamaManager.isReady) { _, isReady in
            if isReady {
                // Add delay to allow progress bar animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onContinue()
                }
            }
        }
    }
}

struct ModelSelectionView: View {
    @ObservedObject var ollamaManager: OllamaManager
    @Binding var selectedModel: String
    var onContinue: () -> Void
    @State private var modelSelectionMode: ModelSelectionMode = .existing
    @State private var newModelName: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadStatus: String = ""
    @State private var downloadTimer: Timer?
    @State private var downloadingModelName: String = ""
    
    enum ModelSelectionMode: String, CaseIterable {
        case none = "none"
        case existing = "existing"
        case download = "download"
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header with icon
            VStack(spacing: 16) {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Model Selection")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose an AI model for sentiment analysis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

              if !selectedModel.isEmpty {
                  HStack {
                      Image(systemName: "checkmark.circle.fill")
                          .foregroundColor(.green)
                      Text("Selected: \(selectedModel)")
                          .font(.body)
                          .fontWeight(.semibold)
                  }
                  .padding()
                  .background(Color.green.opacity(0.1))
                  .cornerRadius(8)
              }
            }
            
            // Model selection mode
            VStack(spacing: 20) {
                Picker("", selection: $modelSelectionMode) {
                    Text("Existing Model").tag(ModelSelectionMode.existing)
                    Text("Download New").tag(ModelSelectionMode.download)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(isDownloading)
                
                if ollamaManager.availableModels.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        
                        Text("No models found")
                            .font(.headline)
                        
                        Text("Please download a model first to continue with sentiment analysis.")
                            .font(.body)
                        .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                } else if modelSelectionMode == .existing {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available Models")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(spacing: 16) {
                            if !selectedModel.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Selected: \(selectedModel)")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Picker("Select a model", selection: $selectedModel) {
                                ForEach(ollamaManager.availableModels.sorted(), id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 300)
                            .onAppear {
                                print("[ModelSelectionView] Available models: \(ollamaManager.availableModels)")
                                print("[ModelSelectionView] Selected model: '\(selectedModel)'")
                                // Ensure selectedModel matches one of the available models
                                if !ollamaManager.availableModels.contains(selectedModel) && !ollamaManager.availableModels.isEmpty {
                                    selectedModel = ollamaManager.availableModels.first!
                                    print("[ModelSelectionView] Updated selected model to: '\(selectedModel)'")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                } else if modelSelectionMode == .download {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Download New Model")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(spacing: 16) {
                            if isDownloading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.2)
                                
                                VStack(spacing: 8) {
                                Text("Downloading \(downloadingModelName)...")
                                        .font(.headline)
                                    
                                    Text(downloadStatus)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                }
                                
                                Button("Cancel Download") {
                                    cancelDownload()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        } else if !downloadStatus.isEmpty && downloadStatus.contains("Failed") {
                            // Show error state
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                                
                                Text("Download Failed")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text(downloadStatus)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Try Again") {
                                    // Reset error state and show download form
                                    downloadStatus = ""
                                    newModelName = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 20) {
                                HStack(spacing: 12) {
                                    TextField("Model name (e.g. gemma3:4b)", text: $newModelName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .font(.body)
                                    
                                    Button(action: {
                                        if !newModelName.isEmpty {
                                            startDownload()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "square.and.arrow.down")
                                                .font(.title3)
                                            Text("Download")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        .frame(minWidth: 120, minHeight: 40)
                                    }
                                    .disabled(newModelName.isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                }
                                
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                    Link("Browse available models", destination: URL(string: "https://ollama.com/library")!)
                                        .foregroundColor(.blue)
                                }
                                .font(.caption)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
            // Continue button
            Button("Continue to File Import") {
                    onContinue()
                }
                .disabled(selectedModel.isEmpty || isDownloading)
                .opacity(modelSelectionMode == .download ? 0 : 1)
                .buttonStyle(.borderedProminent)
            .controlSize(.large)
            }
            .frame(maxWidth: 600)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            cancelDownload()
        }
    }
    
    private func startDownload() {
        isDownloading = true
        downloadingModelName = newModelName
        downloadStatus = "Starting download..."
        
        // Use OllamaManager's API-based download method
        ollamaManager.downloadModel(named: newModelName)
        
        // Monitor the download progress
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !ollamaManager.isDownloading {
                timer.invalidate()
                
                DispatchQueue.main.async {
                    // Check for errors first
                    if ollamaManager.hasError {
                        downloadStatus = "Failed: " + ollamaManager.statusMessage
                        isDownloading = false
                        downloadingModelName = ""
                    } else {
                        // If no error, assume success (the API returned success)
                        downloadStatus = "Model downloaded successfully!"
                        
                        // Refresh available models to make sure the new model appears
                        ollamaManager.refreshAvailableModels()
                        
                        // Wait a moment then update UI
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isDownloading = false
                            downloadingModelName = ""
                            downloadStatus = ""
                            newModelName = ""
                            
                            // Switch to existing models view and select the new model
                            modelSelectionMode = .existing
                            selectedModel = newModelName
                        }
                    }
                }
            } else {
                // Update status from OllamaManager
                DispatchQueue.main.async {
                    downloadStatus = ollamaManager.statusMessage
                }
            }
        }
    }
    
    private func startPolling() {
        downloadTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            pollForModel()
        }
    }
    
    private func pollForModel() {
        // Use OllamaManager's API-based list method
        ollamaManager.refreshAvailableModels()
        
        DispatchQueue.main.async {
            if ollamaManager.availableModels.contains(downloadingModelName) {
                // Model is now available
                downloadStatus = "Model downloaded successfully!"
                
                // Stop polling
                downloadTimer?.invalidate()
                downloadTimer = nil
                
                // Wait a moment then update UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isDownloading = false
                    downloadingModelName = ""
                    downloadStatus = ""
                    newModelName = ""
                    
                    // Switch to existing models view and select the new model
                    modelSelectionMode = .existing
                    selectedModel = downloadingModelName
                }
            } else {
                // Update status message
                downloadStatus = "Downloading model... Please wait."
            }
        }
    }
    
    private func cancelDownload() {
        downloadTimer?.invalidate()
        downloadTimer = nil
        isDownloading = false
        downloadingModelName = ""
        downloadStatus = ""
    }
} 