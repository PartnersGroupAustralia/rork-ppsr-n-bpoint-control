//
//  CardsViewModel.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation
import Observation

/// State and logic for the Cards tab.
/// Validates, deduplicates, and manages a queue of cards waiting to be tested.
@Observable
final class CardsViewModel {

    // MARK: - Published state

    var rawText: String = "" {
        didSet {
            // Auto-validate as the user types/pastes, but don't save automatically.
            if rawText != oldValue {
                updateValidationCounts()
            }
        }
    }

    private(set) var validCount: Int = 0
    private(set) var skippedCount: Int = 0
    private(set) var saveResult: String?
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let engine: PpsrAutomationEngine

    init(engine: PpsrAutomationEngine) {
        self.engine = engine
        updateValidationCounts()
    }

    // MARK: - Computed

    /// Whether the editor has any non-whitespace content.
    var hasContent: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Cards currently waiting in the engine queue.
    var queuedCards: [CardEntry] { engine.cards }

    /// Whether any cards are waiting to be tested.
    var hasQueuedCards: Bool { !engine.cards.isEmpty }

    // MARK: - Actions

    /// Updates valid/skipped counts from the current editor text.
    private func updateValidationCounts() {
        let result = CardFormatter.process(rawText)
        validCount = result.valid.count
        skippedCount = result.skipped
    }

    /// Saves the validated cards from the editor into the engine queue.
    /// Appends to existing cards, skipping duplicates by card number.
    func saveToQueue() {
        guard validCount > 0 else {
            errorMessage = "No valid card lines to save."
            return
        }
        let (valid, skipped) = engine.addCards(rawText)
        validCount = valid
        skippedCount = skipped
        saveResult = "Saved \(valid) card\(valid == 1 ? "" : "s") to the queue."
        errorMessage = nil
    }

    /// Removes a single card from the queue.
    func removeCard(at index: Int) {
        engine.removeCard(at: index)
    }

    /// Clears the entire queue of waiting cards.
    func clearQueue() {
        engine.clearCards()
    }

    /// Clears the editor only (queue is preserved).
    func clearEditor() {
        rawText = ""
        saveResult = nil
    }

    /// Clears the editor and counts.
    func clear() {
        rawText = ""
        validCount = 0
        skippedCount = 0
        saveResult = nil
        errorMessage = nil
    }

    /// Clear any error message.
    func clearError() {
        errorMessage = nil
    }
}
