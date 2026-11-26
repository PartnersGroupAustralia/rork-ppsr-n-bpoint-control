//
//  SettingsViewModel.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation
import Observation

/// State and logic for the Settings tab.
/// Exports successful cards from the on-device automation engine.
@Observable
final class SettingsViewModel {

    // MARK: - Published state

    private(set) var isExporting = false
    private(set) var exportedData: Data?
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let engine: PpsrAutomationEngine

    init(engine: PpsrAutomationEngine) {
        self.engine = engine
    }

    // MARK: - Actions

    /// Export successful cards from the engine's in-memory data.
    func exportSuccessful() {
        isExporting = true
        errorMessage = nil
        exportedData = engine.exportSuccessful()
        if exportedData?.isEmpty ?? true {
            errorMessage = "No successful cards to export."
        }
        isExporting = false
    }

    /// Clear any error message.
    func clearError() {
        errorMessage = nil
    }
}
