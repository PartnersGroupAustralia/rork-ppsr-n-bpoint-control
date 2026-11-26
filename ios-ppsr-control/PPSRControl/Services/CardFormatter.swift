//
//  CardFormatter.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation

/// Utilities for masking, detecting, and parsing credit card strings in multiple text formats.
/// Full card numbers are never persisted — only masked representations are stored in results.
///
/// Supported formats (auto-detected per line):
///   - `card|mm|yy|cvv|vin`   (pipe-delimited, 5 fields)
///   - `card|mm|yy|cvv`       (pipe-delimited, 4 fields — VIN optional)
///   - `card mm/yy cvv`       (space-delimited, combined expiry, 3 fields)
///   - `card mm/yy cvv vin`   (space-delimited, combined expiry + VIN, 4 fields)
///   - `card mm yy cvv`       (space-delimited, separate expiry, 4 fields)
///   - `card mm yy cvv vin`   (space-delimited, separate expiry + VIN, 5 fields)
enum CardFormatter {

    // MARK: - Masking

    /// Masks a card number to `xxxx****xxxx` format, keeping the first and last 4 digits.
    /// Cards shorter than 8 characters are fully masked except the last 2 digits.
    static func mask(_ card: String) -> String {
        let trimmed = card.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 8 else {
            let len = trimmed.count
            if len <= 2 { return String(repeating: "*", count: max(len, 0)) }
            return String(repeating: "*", count: len - 2) + trimmed.suffix(2)
        }
        let first4 = trimmed.prefix(4)
        let last4 = trimmed.suffix(4)
        return "\(first4)****\(last4)"
    }

    // MARK: - Format Detection

    /// Detected card line format.
    enum CardFormat: String {
        case pipeFull          // card|mm|yy|cvv|vin
        case pipeNoVin         // card|mm|yy|cvv
        case spaceCombined     // card mm/yy cvv
        case spaceCombinedVin  // card mm/yy cvv vin
        case spaceSeparate     // card mm yy cvv
        case spaceSeparateVin  // card mm yy cvv vin
        case unknown
    }

    /// Detects the format of a single card line by inspecting delimiters and field count.
    static func detectFormat(_ line: String) -> CardFormat {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .unknown }

        if trimmed.contains("|") {
            let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            switch parts.count {
            case 5: return .pipeFull
            case 4: return .pipeNoVin
            default: return .unknown
            }
        }

        // Space-delimited: split by whitespace
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }

        // Check if any field contains "/" (combined expiry mm/yy)
        let hasCombinedExpiry = parts.contains { $0.contains("/") }

        switch parts.count {
        case 3 where hasCombinedExpiry: return .spaceCombined
        case 4 where hasCombinedExpiry: return .spaceCombinedVin
        case 4 where !hasCombinedExpiry: return .spaceSeparate
        case 5 where !hasCombinedExpiry: return .spaceSeparateVin
        default: return .unknown
        }
    }

    // MARK: - Validation

    /// Validates a single line in any supported format.
    /// - Card: 12–19 digits
    /// - MM: 01–12
    /// - YY: 2 digits
    /// - CVV: 3–4 digits
    /// - VIN: 1–17 alphanumeric characters (optional — empty is valid)
    static func isValidLine(_ line: String) -> Bool {
        let format = detectFormat(line)
        guard format != .unknown else { return false }
        guard let parsed = parse(line) else { return false }

        // Card: 12–19 digits
        guard parsed.card.count >= 12, parsed.card.count <= 19,
              parsed.card.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) })
        else { return false }

        // Month: 01–12
        guard parsed.mm.count == 2,
              let month = Int(parsed.mm), month >= 1, month <= 12,
              parsed.mm.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) })
        else { return false }

        // Year: 2 digits
        guard parsed.yy.count == 2,
              parsed.yy.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) })
        else { return false }

        // CVV: 3–4 digits
        guard parsed.cvv.count >= 3, parsed.cvv.count <= 4,
              parsed.cvv.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) })
        else { return false }

        // VIN: 0–17 alphanumeric (empty is valid — will be auto-generated)
        guard parsed.vin.count <= 17,
              parsed.vin.isEmpty || parsed.vin.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) })
        else { return false }

        return true
    }

    // MARK: - Parsing

    /// Parses a line in any supported format into a `CardEntry`.
    /// Returns nil if the format is unrecognized or fields are missing.
    static func parse(_ line: String) -> CardEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let format = detectFormat(trimmed)
        guard format != .unknown else { return nil }

        let card: String
        let mm: String
        let yy: String
        let cvv: String
        let vin: String

        switch format {
        case .pipeFull:
            let parts = splitPipe(trimmed, count: 5)
            card = parts[0]; mm = parts[1]; yy = parts[2]; cvv = parts[3]; vin = parts[4]

        case .pipeNoVin:
            let parts = splitPipe(trimmed, count: 4)
            card = parts[0]; mm = parts[1]; yy = parts[2]; cvv = parts[3]; vin = ""

        case .spaceCombined:
            let parts = splitSpace(trimmed, count: 3)
            card = parts[0]
            let expiry = parts[1].split(separator: "/")
            mm = expiry.count == 2 ? String(expiry[0]) : ""
            yy = expiry.count == 2 ? String(expiry[1]) : ""
            cvv = parts[2]; vin = ""

        case .spaceCombinedVin:
            let parts = splitSpace(trimmed, count: 4)
            card = parts[0]
            let expiry = parts[1].split(separator: "/")
            mm = expiry.count == 2 ? String(expiry[0]) : ""
            yy = expiry.count == 2 ? String(expiry[1]) : ""
            cvv = parts[2]; vin = parts[3]

        case .spaceSeparate:
            let parts = splitSpace(trimmed, count: 4)
            card = parts[0]; mm = parts[1]; yy = parts[2]; cvv = parts[3]; vin = ""

        case .spaceSeparateVin:
            let parts = splitSpace(trimmed, count: 5)
            card = parts[0]; mm = parts[1]; yy = parts[2]; cvv = parts[3]; vin = parts[4]

        case .unknown:
            return nil
        }

        return CardEntry(card: card, mm: mm, yy: yy, cvv: cvv, vin: vin)
    }

    // MARK: - Splitting Helpers

    /// Splits a pipe-delimited line into exactly `count` trimmed fields.
    private static func splitPipe(_ line: String, count: Int) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .padding(to: count, with: "")
    }

    /// Splits a whitespace-delimited line into exactly `count` trimmed fields.
    private static func splitSpace(_ line: String, count: Int) -> [String] {
        line.split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
            .padding(to: count, with: "")
    }

    // MARK: - Batch Processing

    /// Parses a multi-line card list and returns validated, deduplicated entries plus skipped count.
    /// Supports mixed formats — each line is independently detected.
    /// - Removes empty lines, trims whitespace, skips invalid lines, and deduplicates.
    static func process(_ raw: String) -> (valid: [CardEntry], skipped: Int) {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var seen: Set<String> = []
        var valid: [CardEntry] = []
        var skipped = 0

        for line in lines {
            guard isValidLine(line) else {
                skipped += 1
                continue
            }
            // Dedupe by card number only (VIN may be auto-generated)
            guard let entry = parse(line) else {
                skipped += 1
                continue
            }
            let dedupeKey = entry.card
            guard !seen.contains(dedupeKey) else {
                skipped += 1
                continue
            }
            seen.insert(dedupeKey)
            valid.append(entry)
        }

        return (valid, skipped)
    }
}

// MARK: - Array Padding

private extension Array {
    /// Pads or truncates the array to the specified length.
    func padding(to length: Int, with element: Element) -> [Element] {
        if count >= length { return Array(prefix(length)) }
        return self + Array(repeating: element, count: length - count)
    }
}
