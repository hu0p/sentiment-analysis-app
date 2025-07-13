import SwiftUI
#if os(macOS)
import AppKit
#endif

struct OllamaSetupView: View {
    @ObservedObject var ollamaManager: OllamaManager
    var onContinue: () -> Void

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