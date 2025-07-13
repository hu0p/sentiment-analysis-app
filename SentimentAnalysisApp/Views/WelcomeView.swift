import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack {
            VStack(spacing: 40) {
                // Header section
                VStack(spacing: 24) {
                                    Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    
            Text("Sentiment Analysis")
                .font(.largeTitle)
                .fontWeight(.bold)
                    
                    Text("Analyze the sentiment of arbitrary spreadsheet text using local AI models")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
                
                // Feature highlights
                VStack(spacing: 20) {
                    FeatureRow(icon: "doc.text.magnifyingglass", title: "Import CSV/XLSX Files", description: "Import your data and select which column to analyze.")
                    FeatureRow(icon: "brain.head.profile", title: "Local, Offline AI Analysis", description: "Process data locally using Ollama models without leaking sensitive data")
                    FeatureRow(icon: "chart.bar.doc.horizontal", title: "Detailed Results", description: "View total comments counts and quantities of \"Positive\", \"Mixed\", \"Negative\", or \"Neutral\" sentiments.")
                    FeatureRow(icon: "square.and.arrow.up", title: "Export Results", description: "Download your analysis as CSV files")
                }
                .padding(.horizontal)
                
                // Get started button
            Button(action: onContinue) {
                    HStack(spacing: 12) {
                Text("Get Started")
                    .font(.title2)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.title3)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(minWidth: 400, maxWidth: 600)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
                        .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
    }
} 