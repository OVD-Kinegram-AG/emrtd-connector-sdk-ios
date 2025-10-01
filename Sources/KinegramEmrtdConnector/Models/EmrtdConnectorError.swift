import Foundation

/// Errors that can occur during eMRTD connector operations
public enum EmrtdConnectorError: LocalizedError {
    // Connection errors
    case connectionFailed(underlying: Error?)
    case connectionClosed(reason: String?)
    case connectionTimeout
    case notConnected
    case noNetworkConnection

    // Protocol errors
    case protocolError(message: String)
    case unexpectedMessage(expected: MessageType, received: String)
    case invalidServerResponse(String)
    case handoverFailed(reason: String)
    case handbackFailed(reason: String)

    // WebSocket errors
    case webSocketError(Error)
    case messageSendFailed(Error)
    case messageDecodingFailed(Error)

    // NFC errors
    case nfcNotAvailable(reason: String)
    case nfcSessionFailed(Error)
    case nfcTimeout
    case chipReadError(Error)
    case incompleteRead(missingFiles: [String], reason: String)

    // State errors
    case invalidState(current: String, expected: String)
    case sessionExpired

    // Server errors
    case serverError(code: Int, message: String?, reason: CloseReason?)
    case validationFailed(result: ValidationResult)

    // Binary transfer errors
    case fileTransferFailed(fileId: String, reason: String)
    case chunkedTransferIncomplete(fileId: String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error?.localizedDescription ?? "Unknown error")"

        case .connectionClosed(let reason):
            return "Connection closed: \(reason ?? "No reason provided")"

        case .connectionTimeout:
            return "Connection timed out"

        case .notConnected:
            return "Not connected to server"

        case .noNetworkConnection:
            return "No network connection available"

        case .protocolError(let message):
            return "Protocol error: \(message)"

        case .unexpectedMessage(let expected, let received):
            return "Expected \(expected) message, but received \(received)"

        case .invalidServerResponse(let details):
            return "Invalid server response: \(details)"

        case .handoverFailed(let reason):
            return "CA handover failed: \(reason)"

        case .handbackFailed(let reason):
            return "CA handback failed: \(reason)"

        case .webSocketError(let error):
            return "WebSocket error: \(error.localizedDescription)"

        case .messageSendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"

        case .messageDecodingFailed(let error):
            return "Failed to decode message: \(error.localizedDescription)"

        case .nfcNotAvailable(let reason):
            return "NFC not available: \(reason)"

        case .nfcSessionFailed(let error):
            return "NFC session failed: \(error.localizedDescription)"

        case .nfcTimeout:
            return "NFC session timed out"

        case .chipReadError(let error):
            return "Failed to read chip: \(error.localizedDescription)"

        case .incompleteRead(let missingFiles, let reason):
            let fileList = missingFiles.joined(separator: ", ")
            return "Incomplete read - missing files: \(fileList). \(reason)"

        case .invalidState(let current, let expected):
            return "Invalid state: current=\(current), expected=\(expected)"

        case .sessionExpired:
            return "Session has expired"

        case .serverError(let code, let message, let reason):
            if let reason = reason {
                return reason.localizedDescription
            } else if let message = message {
                return message // Use the server's error message directly
            } else {
                return "Server error \(code)"
            }

        case .validationFailed(let result):
            return "Validation failed with status: \(result.status)"

        case .fileTransferFailed(let fileId, let reason):
            return "File transfer failed for \(fileId): \(reason)"

        case .chunkedTransferIncomplete(let fileId):
            return "Chunked transfer incomplete for file: \(fileId)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .connectionClosed, .connectionTimeout:
            return "Check your network connection and try again"

        case .notConnected:
            return "Call connect() before starting validation"

        case .noNetworkConnection:
            return "Check your internet connection and try again"

        case .nfcNotAvailable:
            return "Enable NFC in Settings or use a device that supports NFC"

        case .nfcTimeout:
            return "Hold the document steady on the device and try again"

        case .incompleteRead:
            return "Hold the document steady on the device throughout the entire reading process and try again"

        case .sessionExpired:
            return "Start a new validation session"

        default:
            return nil
        }
    }
}
