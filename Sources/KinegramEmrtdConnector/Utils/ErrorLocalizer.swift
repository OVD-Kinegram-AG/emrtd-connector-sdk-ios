import Foundation
import KinegramEmrtd

/// Provides localized error messages for common error scenarios
public class ErrorLocalizer {

    /// Get a user-friendly error message
    public static func localizedMessage(for error: Error) -> String {
        // Check for specific connector errors
        if let connectorError = error as? EmrtdConnectorError {
            return localizedConnectorError(connectorError)
        }

        // Check for KinegramEmrtd errors
        if let emrtdError = error as? KinegramEmrtd.EmrtdReaderError {
            return localizedEmrtdError(emrtdError)
        }

        // Check for EmrtdChipCommunicationError
        if let chipError = error as? KinegramEmrtd.EmrtdChipCommunicationError {
            return localizedChipError(chipError)
        }

        // Check for network errors
        if let urlError = error as? URLError {
            return localizedURLError(urlError)
        }

        // Check for NFC errors
        if error.localizedDescription.contains("NFC") ||
           error.localizedDescription.contains("Tag connection lost") {
            return localizedNFCError(error)
        }

        // Default fallback
        return error.localizedDescription
    }

    /// Get a recovery suggestion for an error
    public static func recoverySuggestion(for error: Error) -> String? {
        if let connectorError = error as? EmrtdConnectorError {
            return connectorError.recoverySuggestion
        }

        if error.localizedDescription.contains("Tag connection lost") {
            return "Hold the document steady on the device and try again"
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Check your internet connection and try again"
            case .timedOut:
                return "The request timed out. Please try again"
            case .cannotFindHost, .cannotConnectToHost:
                return "Cannot connect to server. Check the server URL and try again"
            default:
                return "Check your network connection and try again"
            }
        }

        if let emrtdError = error as? KinegramEmrtd.EmrtdReaderError {
            switch emrtdError {
            case .ConnectionLost:
                return "Hold the document steady on the device and try again"
            case .IncorrectAccessKey:
                return "Check the MRZ or CAN and try again"
            default:
                return nil
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private static func localizedConnectorError(_ error: EmrtdConnectorError) -> String {
        // The error already has good localized descriptions
        return error.localizedDescription
    }

    private static func localizedChipError(_ error: KinegramEmrtd.EmrtdChipCommunicationError) -> String {
        switch error {
        case .APDUResponseError(let sw1, let sw2):
            let sw = (UInt16(sw1) << 8) | UInt16(sw2)
            return "Chip communication error (SW: 0x\(String(format: "%04X", sw)))"
        case .SecureMessagingProtectFailed:
            return "Failed to encrypt communication with chip"
        case .SecureMessagingUnprotectFailed:
            return "Failed to decrypt communication from chip"
        case .UnexpectedFileFormat:
            return "Unexpected file format on passport"
        case .NFCError(let nfcError):
            return "NFC error: \(nfcError.localizedDescription)"
        case .UnexpectedError:
            return "Unexpected error reading passport"
        case .ReadBinaryOffsetTooLarge:
            return "File on passport is too large to read"
        @unknown default:
            return "Chip communication error"
        }
    }

    private static func localizedEmrtdError(_ error: KinegramEmrtd.EmrtdReaderError) -> String {
        switch error {
        case .NFCNotSupported:
            return "NFC is not supported on this device"
        case .MoreThanOneTagFound:
            return "Multiple passports detected. Please present only one document"
        case .WrongTag:
            return "Invalid tag type. Please present a valid passport"
        case .UserInvalidatedSession:
            return "NFC session cancelled by user"
        case .SessionInvalidated(let code):
            if let code = code {
                return "NFC session ended: \(code.rawValue)"
            }
            return "NFC session ended unexpectedly"
        case .ConnectingFailed:
            return "Failed to connect to passport chip"
        case .ConnectionLost:
            return "Connection to passport lost. Please hold the document steady"
        case .PaceOrBacFailed:
            return "Authentication with passport failed"
        case .FileReadFailed(_, let files):
            return "Failed to read passport data: \(files.map { $0.protocolName }.joined(separator: ", "))"
        case .IncorrectAccessKey(let remainingAttempts):
            if remainingAttempts > 0 {
                return "Incorrect access key. \(remainingAttempts) attempts remaining"
            } else {
                return "Incorrect access key. Document may be blocked"
            }
        case .InvalidHandoverData:
            return "Invalid data received from server"
        case .ChipAuthenticationFailed:
            return "Chip authentication failed. The document may be invalid"
        @unknown default:
            return "Unknown passport reading error"
        }
    }

    private static func localizedURLError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "No internet connection"
        case .timedOut:
            return "Connection timed out"
        case .cannotFindHost:
            return "Cannot find server"
        case .cannotConnectToHost:
            return "Cannot connect to server"
        case .networkConnectionLost:
            return "Network connection lost"
        case .dnsLookupFailed:
            return "DNS lookup failed"
        case .httpTooManyRedirects:
            return "Too many redirects"
        case .resourceUnavailable:
            return "Resource unavailable"
        case .notConnectedToInternet:
            return "Not connected to internet"
        case .internationalRoamingOff:
            return "International roaming is off"
        case .secureConnectionFailed:
            return "Secure connection failed"
        case .serverCertificateHasBadDate:
            return "Server certificate has expired"
        case .serverCertificateUntrusted:
            return "Server certificate is untrusted"
        default:
            return "Network error: \(error.code.rawValue)"
        }
    }

    private static func localizedNFCError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("tag connection lost") ||
           description.contains("tag was lost") {
            return "Connection to passport lost. Please try again"
        }

        if description.contains("session invalidated") {
            return "NFC session ended unexpectedly"
        }

        if description.contains("timeout") {
            return "NFC operation timed out"
        }

        if description.contains("cancelled") {
            return "NFC operation was cancelled"
        }

        return "NFC error: \(error.localizedDescription)"
    }
}

/// Error display information
public struct ErrorDisplayInfo {
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
    public let isRetryable: Bool

    public init(for error: Error) {
        self.title = Self.title(for: error)
        self.message = ErrorLocalizer.localizedMessage(for: error)
        self.recoverySuggestion = ErrorLocalizer.recoverySuggestion(for: error)
        self.isRetryable = Self.isRetryable(error)
    }

    private static func title(for error: Error) -> String {
        if error is EmrtdConnectorError {
            return "Connection Error"
        }

        if error.localizedDescription.contains("NFC") ||
           error.localizedDescription.contains("Tag") {
            return "NFC Error"
        }

        if error is URLError {
            return "Network Error"
        }

        if error is KinegramEmrtd.EmrtdReaderError {
            return "Passport Reading Error"
        }

        return "Error"
    }

    private static func isRetryable(_ error: Error) -> Bool {
        // Connection errors are usually retryable
        if let connectorError = error as? EmrtdConnectorError {
            switch connectorError {
            case .connectionFailed, .connectionClosed, .connectionTimeout,
                 .nfcTimeout, .webSocketError:
                return true
            default:
                return false
            }
        }

        // Network errors are usually retryable
        if error is URLError {
            return true
        }

        // NFC timeout/lost connection is retryable
        if error.localizedDescription.contains("Tag connection lost") ||
           error.localizedDescription.contains("timeout") {
            return true
        }

        return false
    }
}
