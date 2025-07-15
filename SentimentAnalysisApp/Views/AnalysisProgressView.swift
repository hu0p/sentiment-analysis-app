import SwiftUI

struct AnalysisProgressView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    var onContinue: () -> Void
    var onCancel: (() -> Void)? = nil
    @State private var hasTriggeredAutoContinue = false
    
    var body: some View {
        print("[AnalysisProgressView] body recomputed")
        return VStack {
            VStack(spacing: 32) {
                // Header with icon
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .symbolEffect(.bounce, options: .repeating, value: viewModel.isAnalyzing)
                    
                    Text("Analyzing Sentiments")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                // Progress section
                VStack(spacing: 20) {
                    // File name information
                    if !viewModel.currentFileName.isEmpty {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text(viewModel.currentFileName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    // Model information
                    if !viewModel.currentModel.isEmpty {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("Using model: \(viewModel.currentModel)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Progress bar with percentage
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(.linear)
                            .scaleEffect(y: 1.5)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                    }
                    .padding(.horizontal)
                    
                    // Status message with better styling
                    VStack(spacing: 8) {
                        Text(viewModel.statusMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Abort", role: .cancel) {
                        onCancel?()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: 500)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete && !hasTriggeredAutoContinue {
                hasTriggeredAutoContinue = true
                // Wait a moment before auto-continuing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
                }
            }
        }
    }
} 