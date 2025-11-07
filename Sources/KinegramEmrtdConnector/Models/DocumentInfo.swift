import Foundation

/// High-level document type to help the SDK decide if PACE polling is required.
public enum DocumentType: Hashable {
    case passport
    case idCard
}

/// Policy to determine when PACE polling should be enabled automatically.
///
/// This focuses on known combinations that require PACE polling to be detected
/// on iOS (e.g., some national ID cards). The policy is conservative: passports
/// default to no PACE polling.
public enum PACEPolicy {
    /// Countries (ISO 3166-1 alpha-3) where national ID cards typically require PACE polling
    /// to be detected by CoreNFC on iOS.
    private static let idCardsRequiringPACEPolling: Set<String> = [
        "FRA", // French ID card
        "OMN"  // Omani ID card
    ]

    /// Decide whether PACE polling should be enabled based on document type and issuing country.
    /// - Parameters:
    ///   - documentType: `.passport` or `.idCard`
    ///   - issuingCountryCode: Three-letter ISO 3166-1 alpha-3 code (e.g., "FRA")
    /// - Returns: `true` if PACE polling should be enabled, `false` otherwise
    public static func requiresPACEPolling(for documentType: DocumentType, issuingCountryCode: String) -> Bool {
        let country = issuingCountryCode.uppercased()

        switch documentType {
        case .passport:
            // Do not enable PACE polling for passports by default
            return false

        case .idCard:
            return idCardsRequiringPACEPolling.contains(country)
        }
    }
}

// MARK: - MRZ Helpers

public extension DocumentType {
    /// Determine the document type from an MRZ document code prefix.
    ///
    /// Examples:
    /// - "ID" -> `.idCard`
    /// - "I<" -> `.idCard`
    /// - "P<", "PM", "PO" -> `.passport`
    ///
    /// The rule is simple and conservative: if the string begins with "I"
    /// (case-insensitive), treat it as an ID card; otherwise treat as passport.
    static func fromMRZDocumentCode(_ code: String) -> DocumentType {
        // Use the first non-whitespace character and check if it's 'I'
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first, String(first).uppercased() == "I" {
            return .idCard
        }
        return .passport
    }

    /// Convenience initializer wrapping `fromMRZDocumentCode(_:)`.
    init(mrzDocumentCode code: String) {
        self = DocumentType.fromMRZDocumentCode(code)
    }
}
