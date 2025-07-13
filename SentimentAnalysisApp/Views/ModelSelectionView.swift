import SwiftUI

struct ModelSelectionView: View {
    @ObservedObject var ollamaManager: OllamaManager
    @Binding var selectedModel: String
    var onContinue: () -> Void
    var onBack: (() -> Void)? = nil
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
        VStack(spacing: 16) {
            HStack {
                if let onBack = onBack {
                    Button(action: { onBack() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                Spacer()
            }
            // Header section
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
            }
            // Main content
            Picker("", selection: $modelSelectionMode) {
                Text("Existing Model").tag(ModelSelectionMode.existing)
                Text("Download New").tag(ModelSelectionMode.download)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .disabled(isDownloading)

            // Shared heading
            Text(modelSelectionMode == .existing ? "Available Models" : "Download New Model")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Conditional content below the heading
            Group {
                if ollamaManager.availableModels.isEmpty && modelSelectionMode == .existing && modelSelectionMode != .download {
                    VStack(spacing: 12) {
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
                    VStack(spacing: 12) {
                        Picker("Select a model", selection: $selectedModel) {
                            ForEach(ollamaManager.availableModels.sorted(), id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
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
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                } else if modelSelectionMode == .download {
                    VStack(spacing: 12) {
                        if isDownloading {
                            VStack(spacing: 12) {
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
                            VStack(spacing: 12) {
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
                                        .padding(5)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .font(.body)
                                    Button(action: {
                                        if !newModelName.isEmpty {
                                            startDownload()
                                        }
                                    }) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Image(systemName: "square.and.arrow.down")
                                                .font(.title3)
                                                .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                                            Text("Download")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
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
                    }
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
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

    private func startDownload() {
        isDownloading = true
        downloadingModelName = newModelName
        downloadStatus = "Starting download..."
        ollamaManager.downloadModel(named: newModelName)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !ollamaManager.isDownloading {
                timer.invalidate()
                DispatchQueue.main.async {
                    if ollamaManager.hasError {
                        downloadStatus = "Failed: " + ollamaManager.statusMessage
                        isDownloading = false
                        downloadingModelName = ""
                    } else {
                        downloadStatus = "Model downloaded successfully!"
                        ollamaManager.refreshAvailableModels()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isDownloading = false
                            downloadingModelName = ""
                            downloadStatus = ""
                            newModelName = ""
                            modelSelectionMode = .existing
                            selectedModel = newModelName
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    downloadStatus = ollamaManager.statusMessage
                }
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