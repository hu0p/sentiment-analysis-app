import SwiftUI
#if os(macOS)
import AppKit
#endif

struct OllamaSetupView: View {
    @ObservedObject var ollamaManager: OllamaManager
    var onContinue: () -> Void
    @State private var showBrewAlert = false
    @State private var brewCancelled = false

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
                Text("Ollama is a free, open-source tool that lets us run powerful AI models locally on our Macs. It enables private, offline AI analysis without sending your data to the cloud. It's the key underlying dependency that makes this app possible.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
                if brewCancelled {
                    Text("Homebrew install cancelled by user.")
                        .foregroundColor(.orange)
                        .font(.body)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: 600)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ollamaManager.startSetup()
            // If the manager is already prompting, show the alert immediately
            if ollamaManager.shouldPromptForBrewInstall {
                showBrewAlert = true
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
        .onChange(of: ollamaManager.shouldPromptForBrewInstall) { _, shouldPrompt in
            showBrewAlert = shouldPrompt
        }
        .alert("Install Ollama with Homebrew?", isPresented: $showBrewAlert) {
            Button("Install", role: .none) {
                brewCancelled = false
                ollamaManager.continueBrewInstall()
            }
            Button("Cancel", role: .cancel) {
                brewCancelled = true
                ollamaManager.shouldPromptForBrewInstall = false
            }
        } message: {
            Text("Homebrew is available. Do you want to install Ollama using Homebrew?")
        }
    }
} 