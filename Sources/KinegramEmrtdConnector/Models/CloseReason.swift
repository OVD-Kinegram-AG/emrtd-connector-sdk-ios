import Foundation

/// Server close reasons for WebSocket v2 protocol
public enum CloseReason: String, CaseIterable {
    // Timeout reasons
    case timeoutWhileWaitingForResponse = "TIMEOUT_WHILE_WAITING_FOR_RESPONSE"
    case timeoutWhileWaitingForStartMessage = "TIMEOUT_WHILE_WAITING_FOR_START_MESSAGE"
    case maxSessionTimeExceeded = "MAX_SESSION_TIME_EXCEEDED"

    // Protocol errors
    case unexpectedMessage = "UNEXPECTED_MESSAGE"
    case invalidStartMessage = "INVALID_START_MESSAGE"

    // Authentication errors
    case accessControlFailed = "ACCESS_CONTROL_FAILED"
    case invalidClientId = "INVALID_CLIENT_ID"
    case invalidAccessKeyValues = "INVALID_ACCESS_KEY_VALUES"

    // Reading errors
    case fileReadError = "FILE_READ_ERROR"
    case nfcChipCommunicationFailed = "NFC_CHIP_COMMUNICATION_FAILED"

    // Server errors
    case emrtdPassportReaderError = "EMRTD_PASSPORT_READER_ERROR"
    case serverError = "SERVER_ERROR"
    case postToResultServerFailed = "POST_TO_RESULT_SERVER_FAILED"
    case communicationFailed = "COMMUNICATION_FAILED"

    /// Human-readable description of the close reason
    public var localizedDescription: String {
        switch self {
        case .timeoutWhileWaitingForResponse:
            return "The server timed out while waiting for a response from the device"
        case .timeoutWhileWaitingForStartMessage:
            return "The server timed out while waiting for the initial connection"
        case .maxSessionTimeExceeded:
            return "The validation session exceeded the maximum allowed time"

        case .unexpectedMessage:
            return "An unexpected message was sent to the server"
        case .invalidStartMessage:
            return "The initial connection message was invalid"

        case .accessControlFailed:
            return "Access control failed. Please check your MRZ or CAN details"
        case .invalidClientId:
            return "The client ID is not valid. Please check your configuration"
        case .invalidAccessKeyValues:
            return "The access key values are invalid. Please check the document number, birth date, and expiry date"

        case .fileReadError:
            return "An error occurred while reading data from the document"
        case .nfcChipCommunicationFailed:
            return "Communication with the document chip failed. Please hold the document steady"

        case .emrtdPassportReaderError:
            return "An error occurred in the document reader"
        case .serverError:
            return "A server error occurred during validation"
        case .postToResultServerFailed:
            return "Failed to send the validation result to your server"
        case .communicationFailed:
            return "Communication with the server failed"
        }
    }

    /// Get close reason from string
    public static func from(_ reasonString: String?) -> CloseReason? {
        guard let reasonString = reasonString else { return nil }
        return CloseReason(rawValue: reasonString)
    }

    /// Expected WebSocket close code for this reason (based on Android implementation)
    public var expectedCloseCode: Int {
        switch self {
        case .timeoutWhileWaitingForResponse,
             .timeoutWhileWaitingForStartMessage,
             .nfcChipCommunicationFailed:
            return 1001

        case .unexpectedMessage,
             .invalidStartMessage,
             .invalidAccessKeyValues:
            return 1008

        case .maxSessionTimeExceeded,
             .fileReadError,
             .emrtdPassportReaderError,
             .serverError,
             .postToResultServerFailed,
             .communicationFailed:
            return 1011

        case .invalidClientId:
            return 4401

        case .accessControlFailed:
            return 4403
        }
    }
}
