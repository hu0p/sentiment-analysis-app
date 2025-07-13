import SwiftUI

struct ResultsSummaryView: View {
    @Binding var results: [SentimentResult]
    var onExport: () -> Void
    var onStartOver: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Results Summary")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: onExport) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Export Results")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button(action: onStartOver) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrowshape.turn.up.backward")
                                .font(.title3)
                            Text("Reset")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            
            Divider()
            
            // Scrollable content
            if results.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No results to display.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Summary statistics and sentiment distribution
                        VStack(spacing: 24) {
                            summarySection
                            
                            Divider()
                            
                            sentimentChartSection
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // All results section
                        VStack(spacing: 16) {
                            Text("All Results (\(results.count) total)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVStack(spacing: 12) {
                                ForEach($results) { $result in
                                    EditableResultRow(result: $result)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    private var summarySection: some View {
        let total = results.count
        let positive = results.filter { $0.sentiment == "positive" }.count
        let negative = results.filter { $0.sentiment == "negative" }.count
        let mixed = results.filter { $0.sentiment == "mixed" }.count
        let neutral = results.filter { $0.sentiment == "neutral" }.count
        
        return VStack(spacing: 16) {
            Text("Summary Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                StatCard(title: "Total", value: "\(total)", color: .blue, icon: "doc.text")
            }
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Positive", value: "\(positive)", color: .green, icon: "face.smiling")
                StatCard(title: "Mixed", value: "\(mixed)", color: .orange, icon: "face.dashed.fill")
                StatCard(title: "Negative", value: "\(negative)", color: .red, icon: "face.dashed")
                StatCard(title: "Neutral", value: "\(neutral)", color: .gray, icon: "moon")
            }
            
         
      
        }
    }
    
    private var sentimentChartSection: some View {
        let positive = results.filter { $0.sentiment == "positive" }.count
        let negative = results.filter { $0.sentiment == "negative" }.count
        let mixed = results.filter { $0.sentiment == "mixed" }.count
        let neutral = results.filter { $0.sentiment == "neutral" }.count
        let total = results.count
        
        return VStack(spacing: 16) {
            Text("Sentiment Distribution")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                SentimentBar(label: "Positive", count: positive, total: total, color: .green)
                SentimentBar(label: "Negative", count: negative, total: total, color: .red)
                SentimentBar(label: "Mixed", count: mixed, total: total, color: .orange)
                SentimentBar(label: "Neutral", count: neutral, total: total, color: .gray)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SentimentBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.body)
                    .frame(width: 60, alignment: .leading)
                
                Text("\(count)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 40, alignment: .trailing)
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                }
                .frame(height: 8)
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct ResultRow: View {
    let result: SentimentResult
    
    private var sentimentColor: Color {
        switch result.sentiment {
        case "positive": return .green
        case "negative": return .red
        case "mixed": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.original)
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundColor(sentimentColor)
                
                Text("Sentiment: \(result.sentiment.capitalized)")
                    .font(.caption)
                    .foregroundColor(sentimentColor)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct EditableResultRow: View {
    @Binding var result: SentimentResult
    @State private var showingSentimentPicker = false
    
    private var sentimentColor: Color {
        switch result.sentiment {
        case "positive": return .green
        case "negative": return .red
        case "mixed": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.original)
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundColor(sentimentColor)
                
                Text("Sentiment: \(result.sentiment.capitalized)")
                    .font(.caption)
                    .foregroundColor(sentimentColor)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingSentimentPicker = true
                }) {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit sentiment")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .scrollablePopover(isPresented: $showingSentimentPicker) {
            SentimentPickerView(selectedSentiment: $result.sentiment)
                .frame(width: 250, height: 250)
        }
    }
}

struct SentimentPickerView: View {
    @Binding var selectedSentiment: String
    @Environment(\.dismiss) private var dismiss
    
    private let sentiments = ["positive", "negative", "mixed", "neutral"]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Sentiment")
                .font(.headline)
                .padding(.top, 16)
            
            VStack(spacing: 8) {
                ForEach(sentiments, id: \.self) { sentiment in
                    HStack {
                        Image(systemName: sentimentIcon(for: sentiment))
                            .foregroundColor(sentimentColor(for: sentiment))
                        Text(sentiment.capitalized)
                            .foregroundColor(selectedSentiment == sentiment ? .white : .primary)
                        Spacer()
                        if selectedSentiment == sentiment {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSentiment == sentiment ? sentimentColor(for: sentiment) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(sentimentColor(for: sentiment), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSentiment = sentiment
                        dismiss()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    private func sentimentColor(for sentiment: String) -> Color {
        switch sentiment {
        case "positive": return .green
        case "negative": return .red
        case "mixed": return .orange
        default: return .gray
        }
    }
    
    private func sentimentIcon(for sentiment: String) -> String {
        switch sentiment {
        case "positive": return "face.smiling"
        case "negative": return "face.dashed"
        case "mixed": return "face.dashed.fill"
        default: return "moon"
        }
    }
} 
