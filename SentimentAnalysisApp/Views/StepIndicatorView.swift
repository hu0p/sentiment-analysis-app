import SwiftUI

struct StepIndicatorView: View {
    let steps: [Step]
    let currentStep: Int
    var showEditIcon: Bool = false
    var editIconStepIndex: Int? = nil
    var onEditModel: (() -> Void)? = nil
    var onWelcomeTap: (() -> Void)? = nil
    var isWelcomeDisabled: Bool = false
    var onModelTap: (() -> Void)? = nil
    var isModelSelectionActive: Bool = false
    var onFileTap: (() -> Void)? = nil
    var isFileStepClickable: Bool = false
    var onColumnTap: (() -> Void)? = nil
    var isColumnStepClickable: Bool = false
    var onResultsTap: (() -> Void)? = nil
    var isResultsStepClickable: Bool = false
    var isAnalysisInProgress: Bool = false
    
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let icon: String?
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \ .offset) { index, step in
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Circle()
                                    .fill(index < currentStep ? Color.blue : (index == currentStep ? Color.accentColor : Color.gray.opacity(0.2)))
                                    .frame(width: 28, height: 28)
                                if let icon = step.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(index <= currentStep ? .white : .gray)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(index <= currentStep ? .white : .gray)
                                }
                            }
                            if showEditIcon && editIconStepIndex == index, let onEditModel = onEditModel {
                                Button(action: onEditModel) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .padding(4)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .offset(x: 14, y: -14)
                                .help("Change model")
                            }
                            if index == 2 && isFileStepClickable && currentStep != 2 {
                                Button(action: { onFileTap?() }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .padding(4)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .offset(x: 14, y: -14)
                                .help("Edit file selection")
                            }
                            if index == 3 && isColumnStepClickable && currentStep != 3 {
                                Button(action: { onColumnTap?() }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .padding(4)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .offset(x: 14, y: -14)
                                .help("Edit column selection")
                            }
                            if index == 5 && isResultsStepClickable && currentStep != 5 {
                                Button(action: { onResultsTap?() }) {
                                    Image(systemName: "eye")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .padding(4)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .offset(x: 14, y: -14)
                                .help("View results")
                            }
                        }
                        Text(step.title)
                            .font(.caption)
                            .foregroundColor(index == currentStep ? .primary : .secondary)
                            .frame(maxWidth: 80)
                            .multilineTextAlignment(.center)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Disable navigation during analysis
                        guard !isAnalysisInProgress else { return }
                        
                        if index == 0, let onWelcomeTap = onWelcomeTap, !isWelcomeDisabled {
                            onWelcomeTap()
                        } else if index == 1, let onModelTap = onModelTap, !isModelSelectionActive {
                            onModelTap()
                        } else if index == 2, let onFileTap = onFileTap, isFileStepClickable {
                            onFileTap()
                        } else if index == 3, let onColumnTap = onColumnTap, isColumnStepClickable {
                            onColumnTap()
                        } else if index == 5, let onResultsTap = onResultsTap, isResultsStepClickable {
                            onResultsTap()
                        }
                    }
                    .opacity((index == 0 && isWelcomeDisabled) || (index == 1 && isModelSelectionActive) || isAnalysisInProgress ? 0.5 : 1.0)
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.2))
                            .frame(width: 32, height: 3)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
} 