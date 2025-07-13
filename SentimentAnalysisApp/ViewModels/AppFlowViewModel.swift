import Foundation
import SwiftUI

class AppFlowViewModel: ObservableObject {
    enum Step {
        case welcome
        case ollamaSetup
        case modelSelection
        case fileImport
        case columnSelection
        case analysisProgress
        case resultsSummary
    }
    
    @Published var currentStep: Step = .welcome
    
    func goToNextStep() {
        switch currentStep {
        case .welcome: currentStep = .ollamaSetup
        case .ollamaSetup: currentStep = .modelSelection
        case .modelSelection: currentStep = .fileImport
        case .fileImport: currentStep = .columnSelection
        case .columnSelection: currentStep = .analysisProgress
        case .analysisProgress: currentStep = .resultsSummary
        case .resultsSummary: break
        }
    }
    
    func resetFlow() {
        currentStep = .welcome
    }

    func goToPreviousStep() {
        switch currentStep {
        case .welcome: break
        case .ollamaSetup: currentStep = .welcome
        case .modelSelection: currentStep = .welcome // skip ollamaSetup
        case .fileImport: currentStep = .modelSelection
        case .columnSelection: currentStep = .fileImport
        case .analysisProgress: currentStep = .columnSelection
        case .resultsSummary: currentStep = .analysisProgress
        }
    }
} 