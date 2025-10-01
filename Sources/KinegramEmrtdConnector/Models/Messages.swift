import Foundation
import KinegramEmrtd

// MARK: - Message Type Enum

public enum MessageType: String, Codable {
    case start = "START"
    case accept = "ACCEPT"
    case caHandover = "CA_HANDOVER"
    case caHandback = "CA_HANDBACK"
    case finish = "FINISH"
    case result = "RESULT"
    case close = "CLOSE"
    case monitoring = "MONITORING"
}

// MARK: - Base Message Protocol

protocol WebSocketMessage: Codable {
    var type: MessageType { get }
}

// MARK: - START Message

struct StartMessage: WebSocketMessage {
    let type = MessageType.start
    let validationId: String
    let clientId: String
    let platform: String = "iOS"
    let nfcAdapterSupportsExtendedLength: Bool = true
    let enableDiagnostics: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case validationId
        case clientId
        case platform
        case nfcAdapterSupportsExtendedLength
        case enableDiagnostics
    }
}

// MARK: - ACCEPT Message

struct AcceptMessage: WebSocketMessage {
    let type = MessageType.accept
    let activeAuthenticationChallenge: String // Base64 encoded

    enum CodingKeys: String, CodingKey {
        case type
        case activeAuthenticationChallenge
    }
}

// MARK: - CA_HANDOVER Message

struct CAHandoverMessage: WebSocketMessage {
    let type = MessageType.caHandover
    let maxTransceiveLengthForSecureMessaging: Int
    let maxBlockSize: Int
    let secureMessagingInfo: SecureMessagingInfo

    enum CodingKeys: String, CodingKey {
        case type
        case maxTransceiveLengthForSecureMessaging
        case maxBlockSize
        case secureMessagingInfo
    }
}

// Use SecureMessagingInfo from KinegramEmrtd to avoid duplication
public typealias SecureMessagingInfo = KinegramEmrtd.SecureMessagingInfo

public struct ChipAuthInfo: Codable {
    public let ephemeralPublicKey: String // Base64
    public let keyAgreementOID: String
    public let cipherOID: String?
    public let keyId: Int

    public enum CodingKeys: String, CodingKey {
        case ephemeralPublicKey
        case keyAgreementOID
        case cipherOID
        case keyId
    }

    public init(ephemeralPublicKey: String, keyAgreementOID: String, cipherOID: String?, keyId: Int) {
        self.ephemeralPublicKey = ephemeralPublicKey
        self.keyAgreementOID = keyAgreementOID
        self.cipherOID = cipherOID
        self.keyId = keyId
    }
}

// MARK: - CA_HANDBACK Message

struct CAHandbackMessage: WebSocketMessage {
    let type = MessageType.caHandback
    let checkResult: String // "SUCCESS", "FAILED", "UNAVAILABLE"
    let secureMessagingInfo: SecureMessagingInfo?
    let dg1Data: String? // Base64
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case type
        case checkResult
        case secureMessagingInfo
        case dg1Data
        case errorMessage
    }
}

// MARK: - FINISH Message

struct FinishMessage: WebSocketMessage {
    let type = MessageType.finish
    let sendResult: Bool
    let activeAuthenticationSignature: String? // Base64

    enum CodingKeys: String, CodingKey {
        case type
        case sendResult
        case activeAuthenticationSignature
    }

    init(sendResult: Bool = true, activeAuthenticationSignature: String? = nil) {
        self.sendResult = sendResult
        self.activeAuthenticationSignature = activeAuthenticationSignature
    }

    // Custom encoding to always include activeAuthenticationSignature field
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(sendResult, forKey: .sendResult)
        // Always encode the field, even if nil
        try container.encode(activeAuthenticationSignature, forKey: .activeAuthenticationSignature)
    }
}

// MARK: - RESULT Message

struct ResultMessage: WebSocketMessage {
    let type = MessageType.result
    let validationResult: ValidationResult
    let details: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case type
        case passport
        case details
    }

    // Custom encoding/decoding for [String: Any]
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(validationResult, forKey: .passport)
        if let details = details {
            let jsonData = try JSONSerialization.data(withJSONObject: details)
            let jsonString = String(data: jsonData, encoding: .utf8)
            try container.encode(jsonString, forKey: .details)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        validationResult = try container.decode(ValidationResult.self, forKey: .passport)
        if let detailsString = try container.decodeIfPresent(String.self, forKey: .details),
           let detailsData = detailsString.data(using: .utf8),
           let details = try JSONSerialization.jsonObject(with: detailsData) as? [String: Any] {
            self.details = details
        } else {
            self.details = nil
        }
    }
}

// MARK: - MONITORING Message

struct MonitoringMessage: WebSocketMessage {
    let type = MessageType.monitoring
    let message: String

    enum CodingKeys: String, CodingKey {
        case type
        case message
    }

    init(message: String) {
        self.message = message
    }
}

/// The final validation result from the server
///
/// This contains all passport data and the results of the three authentication protocols:
///
/// ## Authentication Protocols Explained
///
/// **Passive Authentication (PA)**
/// - Verifies data integrity: ensures passport data hasn't been modified
/// - Checks the digital signature on the passport data (SOD file)
/// - Uses PKI certificates to validate the issuing country's signature
/// - Result: "SUCCEEDED" = data is intact, "FAILED" = data may be tampered
///
/// **Chip Authentication (CA)**
/// - Verifies chip authenticity: ensures the chip is genuine, not cloned
/// - Chip proves it has the private key matching the public key in DG14
/// - Establishes new secure messaging keys for enhanced protection
/// - Result: "SUCCEEDED" = genuine chip, "FAILED" = possible clone
///
/// **Active Authentication (AA)**
/// - Proves the chip is not a copy at this moment
/// - Chip signs a challenge with its private key (from DG15)
/// - Like asking the chip to solve a unique puzzle only it can solve
/// - Result: "SUCCEEDED" = original chip responding, "FAILED" = possible replay
///
/// ## Why All Three?
/// - PA: Ensures data wasn't changed (like a tamper-evident seal)
/// - CA: Ensures chip is genuine (like a hologram)
/// - AA: Ensures chip is responding live (like a live video call vs recording)
public struct ValidationResult: Codable {
    // Raw passport data from server
    public let sodInfo: SODInfo?
    public let mrzInfo: MRZInfo?
    public let facePhoto: String?
    public let signaturePhotos: [String]?
    public let additionalPersonalDetails: AdditionalPersonalDetails?
    public let additionalDocumentDetails: AdditionalDocumentDetails?

    // Authentication results - stored as strings from server
    private let chipAuthenticationResult: String?
    private let activeAuthenticationResult: String?
    private let passiveAuthenticationDetails: PassiveAuthDetails?
    private let passiveAuthentication: Bool?

    // Diagnostic data - only present in result when environment variable
    // WS_ENDPOINT_INCLUDE_BINARY_FILES_IN_RESULT=true is set in DocVal instance. 
    public let filesBinary: [String: String]? // DG files as base64 strings
    public let errors: [String]?

    // Computed properties for compatibility
    public var status: String {
        // Determine overall status based on authentication results

        // Passive Authentication: Check data integrity AND certificate validity
        // - allHashesValid: Ensures document data hasn't been modified
        // - documentCertificateValid: Ensures the certificate chain is trusted (CSCA check)
        // Both MUST be valid for PA to pass when details are available
        let paOk = passiveAuthenticationDetails.map {
            $0.allHashesValid && $0.documentCertificateValid
        } ?? (passiveAuthentication ?? false)

        // Chip Authentication: UNAVAILABLE is acceptable (not all chips support it)
        let caOk = chipAuthenticationResult == "SUCCESS" || chipAuthenticationResult == "UNAVAILABLE"

        // Active Authentication: UNAVAILABLE is acceptable (not all chips support it)
        let aaOk = activeAuthenticationResult == "SUCCESS" || activeAuthenticationResult == "UNAVAILABLE"

        // ALL checks must pass for document to be VALID
        return (paOk && caOk && aaOk) ? "VALID" : "INVALID"
    }

    public var chipAuthResult: String? {
        return chipAuthenticationResult
    }

    public var passiveAuthResult: String? {
        if let details = passiveAuthenticationDetails {
            // Both checks must pass, just like with status
            return (details.allHashesValid && details.documentCertificateValid) ? "VALID" : "FAILED"
        } else if let passed = passiveAuthentication {
            return passed ? "VALID" : "FAILED"
        }
        return nil
    }

    public var activeAuthResult: String? {
        return activeAuthenticationResult
    }

    public var dataGroupChecks: [String: String]? {
        return nil // Not provided in v2 protocol
    }
}

// Passive authentication details from server
struct PassiveAuthDetails: Codable {
    let sodSignatureValid: Bool
    let documentCertificateValid: Bool
    let dataGroupsChecked: [Int]
    let dataGroupsWithValidHash: [Int]
    let error: String?
    let allHashesValid: Bool
}

// Supporting structures for ValidationResult
public struct SODInfo: Codable {
    public let hashAlgorithm: String
    public let hashForDataGroup: [String: String]
}

public struct MRZInfo: Codable {
    public let documentType: String
    public let documentCode: String
    public let issuingState: String
    public let primaryIdentifier: String
    public let secondaryIdentifier: [String]
    public let nationality: String
    public let documentNumber: String
    public let dateOfBirth: String
    public let gender: String
    public let dateOfExpiry: String
    public let optionalData1: String?
    public let optionalData2: String?
}

public struct AdditionalPersonalDetails: Codable {
    // Add fields as needed based on actual server response
}

public struct AdditionalDocumentDetails: Codable {
    // Add fields as needed based on actual server response
}

public struct AuthenticationResult: Codable {
    public let result: String // "SUCCEEDED", "FAILED", "NOT_PERFORMED"
    public let message: String?
}

// Wrapper type that can decode either AuthenticationResult or bool
public enum AuthenticationResultOrBool: Codable {
    case result(AuthenticationResult)
    case boolean(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as AuthenticationResult first
        if let authResult = try? container.decode(AuthenticationResult.self) {
            self = .result(authResult)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else {
            throw DecodingError.typeMismatch(
                AuthenticationResultOrBool.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected AuthenticationResult or Bool"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .result(let authResult):
            try container.encode(authResult)
        case .boolean(let boolValue):
            try container.encode(boolValue)
        }
    }

    // Helper properties
    var isSuccessful: Bool {
        switch self {
        case .result(let authResult):
            return authResult.result == "SUCCEEDED"
        case .boolean(let boolValue):
            return boolValue
        }
    }

    var resultString: String? {
        switch self {
        case .result(let authResult):
            return authResult.result
        case .boolean(let boolValue):
            return boolValue ? "SUCCEEDED" : "FAILED"
        }
    }
}

// MARK: - CLOSE Message

struct CloseMessage: WebSocketMessage {
    let type = MessageType.close
    let reason: String?
    let code: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case reason
        case code
    }
}

// MARK: - Binary Message Types

enum BinaryMessageType: UInt8 {
    case file = 0x01
    case apdu = 0x02
}

// MARK: - Binary FILE Message

struct BinaryFileMessage {
    let messageType = BinaryMessageType.file
    let fileName: String
    let data: Data

    func encode() -> Data {
        var encoded = Data()
        encoded.append(messageType.rawValue)

        // File name as UTF-8
        guard let nameData = fileName.data(using: .utf8) else {
            fatalError("Invalid file name encoding")
        }

        // Name length must fit in one byte
        guard nameData.count <= 255 else {
            fatalError("File name too long: \(nameData.count) bytes")
        }

        // Name length (1 byte)
        encoded.append(UInt8(nameData.count))

        // Name (variable length)
        encoded.append(nameData)

        // Data
        encoded.append(data)

        return encoded
    }

    static func decode(from data: Data) throws -> BinaryFileMessage {
        guard data.count >= 3 else { // 1 + 1 + at least 1 byte for name
            throw MessageError.invalidBinaryMessage
        }

        let messageType = data[0]
        guard messageType == BinaryMessageType.file.rawValue else {
            throw MessageError.wrongMessageType
        }

        // Extract name length
        let nameLength = Int(data[1])
        guard data.count >= 2 + nameLength else {
            throw MessageError.invalidBinaryMessage
        }

        // Extract file name
        let nameData = data[2..<(2 + nameLength)]
        guard let fileName = String(data: nameData, encoding: .utf8) else {
            throw MessageError.decodingFailed("Invalid UTF-8 file name")
        }

        // Extract data
        let fileData = data.suffix(from: 2 + nameLength)

        return BinaryFileMessage(
            fileName: fileName,
            data: fileData
        )
    }
}

// MARK: - Binary APDU Message

struct BinaryAPDUMessage {
    let messageType = BinaryMessageType.apdu
    let data: Data

    func encode() -> Data {
        var encoded = Data()
        encoded.append(messageType.rawValue)
        encoded.append(data)
        return encoded
    }

    static func decode(from data: Data) throws -> BinaryAPDUMessage {
        guard data.count >= 1 else {
            throw MessageError.invalidBinaryMessage
        }

        let messageType = data[0]
        guard messageType == BinaryMessageType.apdu.rawValue else {
            throw MessageError.wrongMessageType
        }

        // Rest is APDU data
        let apduData = data.suffix(from: 1)

        return BinaryAPDUMessage(data: apduData)
    }
}

// MARK: - Error Types

enum MessageError: LocalizedError {
    case invalidBinaryMessage
    case wrongMessageType
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBinaryMessage:
            return "Invalid binary message format"
        case .wrongMessageType:
            return "Unexpected message type"
        case .decodingFailed(let reason):
            return "Message decoding failed: \(reason)"
        }
    }
}
