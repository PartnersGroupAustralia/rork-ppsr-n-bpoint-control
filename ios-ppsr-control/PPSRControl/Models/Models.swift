//
//  Models.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation

/// A parsed card entry from the editor (supports multiple text formats).
/// Held in memory only — never persisted to disk.
struct CardEntry: Identifiable, Hashable {
    let card: String
    let mm: String
    let yy: String
    let cvv: String
    let vin: String

    var id: String { card + vin }

    /// Reconstructs the pipe-delimited line (omits trailing VIN if empty).
    var formatted: String {
        if vin.isEmpty {
            return "\(card)|\(mm)|\(yy)|\(cvv)"
        }
        return "\(card)|\(mm)|\(yy)|\(cvv)|\(vin)"
    }

    /// Export line in the fixed `CARDNUMBER|MM|YY|CVV` shape, regardless of the
    /// format the card was originally pasted in. Month is zero-padded and the
    /// year is reduced to two digits so every exported row is uniform.
    var exportLine: String {
        "\(card)|\(Self.twoDigitMonth(mm))|\(Self.twoDigitYear(yy))|\(cvv)"
    }

    /// Zero-pads a single-digit month (`3` -> `03`).
    private static func twoDigitMonth(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count == 1 else { return digits }
        return "0" + digits
    }

    /// Reduces a four-digit year to two digits (`2029` -> `29`).
    private static func twoDigitYear(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count > 2 else { return digits }
        return String(digits.suffix(2))
    }
}

/// A single PPSR check result produced by the on-device automation engine.
struct PpsrResult: Codable, Identifiable, Hashable {
    /// Masked card number (xxxx****xxxx). Full card numbers are never stored in results.
    let card: String
    let vin: String
    let email: String
    let status: String
    /// Local file path to the screenshot PNG (in the temp directory), or nil if capture failed.
    let screenshot: String?
    let timestamp: String

    /// Synthesized identifier for SwiftUI lists/grids.
    var id: String { card + timestamp }

    /// Masked card number in `xxxx****xxxx` format.
    var maskedCard: String {
        CardFormatter.mask(card)
    }

    /// File URL for the local screenshot, if available.
    var screenshotURL: URL? {
        guard let screenshot, !screenshot.isEmpty else { return nil }
        return URL(fileURLWithPath: screenshot)
    }
}

/// Aggregate PPSR processing statistics (computed from results).
struct PpsrStats: Codable, Equatable {
    let totalProcessed: Int
    let successCount: Int
    let failureCount: Int
    let unknownCount: Int
    let noResultsCount: Int
    let successRate: Double

    enum CodingKeys: String, CodingKey {
        case totalProcessed = "total_processed"
        case successCount = "success_count"
        case failureCount = "failure_count"
        case unknownCount = "unknown_count"
        case noResultsCount = "no_results_count"
        case successRate = "success_rate"
    }

    /// Empty stats (no results yet).
    static let empty = PpsrStats(totalProcessed: 0, successCount: 0,
                                  failureCount: 0, unknownCount: 0,
                                  noResultsCount: 0, successRate: 0)
}

/// Current processing progress.
struct PpsrProgress: Codable, Equatable {
    let currentIndex: Int
    let totalCards: Int

    enum CodingKeys: String, CodingKey {
        case currentIndex = "current_index"
        case totalCards = "total_cards"
    }

    /// Progress fraction in the range 0.0–1.0; 0 when totalCards is 0.
    var fraction: Double {
        guard totalCards > 0 else { return 0 }
        return min(Double(currentIndex) / Double(totalCards), 1.0)
    }
}

/// Automation running status.
struct PpsrStatus: Codable, Equatable {
    let running: Bool
    let pid: Int?
}

/// The automation target picked on the Dashboard: PPSR vehicle checks or the
/// Bpoint payment form (Our Lady of the Way parishes).
enum AutomationMode: String, CaseIterable {
    case ppsr
    case bpoint

    /// Localized label for the Dashboard picker.
    var label: String {
        switch self {
        case .ppsr: "PPSR"
        case .bpoint: "Bpoint"
        }
    }

    /// SF Symbol name for the picker option.
    var iconName: String {
        switch self {
        case .ppsr: "car.side"
        case .bpoint: "creditcard"
        }
    }
}

/// Semantic status categories derived from the raw status string.
enum ResultStatus: String, CaseIterable {
    case resultsFound = "RESULTS_FOUND"
    case paymentError = "PAYMENT_ERROR"
    case unknown = "UNKNOWN"
    case noResults = "NO_RESULTS"

    /// Maps an arbitrary raw string to the nearest known category.
    static func from(_ raw: String) -> ResultStatus {
        ResultStatus(rawValue: raw) ?? .unknown
    }

    /// Localized human-readable label.
    var label: String {
        switch self {
        case .resultsFound: "Results Found"
        case .paymentError: "Payment Error"
        case .unknown: "Unknown"
        case .noResults: "No Results"
        }
    }

    /// SF Symbol name for badges.
    var iconName: String {
        switch self {
        case .resultsFound: "checkmark.seal.fill"
        case .paymentError: "xmark.octagon.fill"
        case .unknown: "exclamationmark.triangle.fill"
        case .noResults: "questionmark.circle.fill"
        }
    }
}
