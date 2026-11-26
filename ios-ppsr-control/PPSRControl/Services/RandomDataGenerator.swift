//
//  RandomDataGenerator.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import Foundation

/// Generates random VINs and email addresses for PPSR automation runs.
/// Each run produces a fresh random email; each card gets a fresh random VIN.
enum RandomDataGenerator {

    // MARK: - VIN

    /// Valid VIN characters (excludes I, O, Q per ISO 3779 to avoid confusion with digits).
    private static let vinLetters = "ABCDEFGHJKLMNPRSTUVWXYZ"
    private static let vinDigits = "0123456789"
    private static let vinCharset = vinLetters + vinDigits

    /// Generates a random 17-character VIN.
    /// Uses alphanumeric characters excluding I, O, Q (per VIN standard).
    static func randomVIN() -> String {
        let length = 17
        var chars: [Character] = []
        for _ in 0..<length {
            let charset = vinCharset
            guard let char = charset.randomElement() else { continue }
            chars.append(char)
        }
        return String(chars)
    }

    // MARK: - Email

    /// Common email domains for realistic generation.
    private static let emailDomains = [
        "gmail.com", "outlook.com", "yahoo.com", "hotmail.com",
        "protonmail.com", "icloud.com", "mail.com", "zoho.com",
    ]

    /// Common username prefixes.
    private static let usernamePrefixes = [
        "user", "test", "check", "auto", "ppsr", "vin", "query",
        "search", "lookup", "verify", "inspect", "scan",
    ]

    /// Generates a random email address.
    static func randomEmail() -> String {
        let prefix = usernamePrefixes.randomElement() ?? "user"
        let number = Int.random(in: 1000...99999)
        let domain = emailDomains.randomElement() ?? "gmail.com"
        return "\(prefix)\(number)@\(domain)"
    }

    // MARK: - Person & Phone (Bpoint)

    /// First names used to build a plausible payer name.
    private static let firstNames = [
        "James", "Olivia", "William", "Charlotte", "Thomas", "Amelia", "Jack",
        "Mia", "Henry", "Sophie", "Oliver", "Grace", "Lucas", "Isla", "Noah",
        "Chloe", "Liam", "Ruby", "Ethan", "Zara", "Daniel", "Ella", "Ryan", "Nora",
    ]

    /// Surnames used to build a plausible payer name.
    private static let lastNames = [
        "Smith", "Wilson", "Taylor", "Brown", "Davies", "Evans", "Thomas",
        "Roberts", "Johnson", "Walker", "Wright", "Thompson", "White", "Hughes",
        "Edwards", "Green", "Lewis", "Wood", "Harris", "Clarke", "Baker", "Hall",
    ]

    /// Generates a random full name for the Bpoint payer details.
    static func randomFullName() -> String {
        "\(firstNames.randomElement() ?? "Alex") \(lastNames.randomElement() ?? "Taylor")"
    }

    /// Generates a random Australian mobile number (04XX XXX XXX).
    static func randomPhone() -> String {
        let rest = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
        return "04" + rest
    }
}
