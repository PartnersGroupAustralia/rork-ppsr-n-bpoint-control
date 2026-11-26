//
//  ResultsViewModel.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation
import Observation

/// State and logic for the Results tab.
/// Reads results from the shared on-device automation engine.
@Observable
final class ResultsViewModel {

    private let engine: PpsrAutomationEngine

    init(engine: PpsrAutomationEngine) {
        self.engine = engine
    }

    // MARK: - Computed

    var results: [PpsrResult] { engine.results }
    var errorMessage: String? { engine.errorMessage }

    /// Only results with status RESULTS_FOUND.
    var successfulResults: [PpsrResult] {
        results.filter { ResultStatus.from($0.status) == .resultsFound }
    }

    // MARK: - Actions

    /// Delete a result and its screenshot from the engine.
    func deleteResult(_ result: PpsrResult) {
        engine.deleteResult(result)
    }

    /// Delete a result at index from the engine.
    func deleteResult(at index: Int) {
        engine.deleteResult(at: index)
    }

    /// Clear any error message.
    func clearError() {
        engine.clearError()
    }
}
