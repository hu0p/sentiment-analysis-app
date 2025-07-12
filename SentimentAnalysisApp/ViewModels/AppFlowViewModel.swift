import Foundation
import SwiftUI

class AppFlowViewModel: ObservableObject {
    enum Step {
        case welcome
        case ollamaSetup
        case modelSelection
        case fileImport
        case analysisProgress
        case resultsSummary
    }
    
    @Published var currentStep: Step = .welcome
    
    func goToNextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .ollamaSetup
        case .ollamaSetup:
            currentStep = .modelSelection
        case .modelSelection:
            currentStep = .fileImport
        case .fileImport:
            currentStep = .analysisProgress
        case .analysisProgress:
            currentStep = .resultsSummary
        case .resultsSummary:
            break
        }
    }
    
    func resetFlow() {
        currentStep = .welcome
    }
} 