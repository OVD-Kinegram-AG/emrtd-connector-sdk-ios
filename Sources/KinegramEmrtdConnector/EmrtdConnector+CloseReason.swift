//
//  EmrtdConnector.CloseReason.swift
//  kinegram_emrtd_connector
//
//  Created by Tim Vogel on 04.01.22.
//

enum CloseReasonRaw {
    static let timeoutWhileWaitingForResponse = "TIMEOUT_WHILE_WAITING_FOR_RESPONSE"
    static let timeoutWhileWaitingForStartMessage = "TIMEOUT_WHILE_WAITING_FOR_START_MESSAGE"
    static let maxSessionTimeExceeded = "MAX_SESSION_TIME_EXCEEDED"
    static let unexpectedMessage = "UNEXPECTED_MESSAGE"
    static let invalidStartMessage = "INVALID_START_MESSAGE"
    static let accessControlFailed = "ACCESS_CONTROL_FAILED"
    static let fileReadError = "FILE_READ_ERROR"
    static let emrtdPassportReaderError = "EMRTD_PASSPORT_READER_ERROR"
    static let serverError = "SERVER_ERROR"
    static let postToResultServerFailed = "POST_TO_RESULT_SERVER_FAILED"
    static let invalidClientId = "INVALID_CLIENT_ID"
    static let invalidAccessKeyValues = "INVALID_ACCESS_KEY_VALUES"
    static let nfcChipCommunicationFailed = "NFC_CHIP_COMMUNICATION_FAILED"
    static let communicationFailed = "COMMUNICATION_FAILED"
}

@available(iOS 13.0, *)
extension EmrtdConnector {

    ///
    /// Close Reasons to expect when the WebSocket Session is closed with an non 1000 Close Code.
    ///
    public enum CloseReason: CustomStringConvertible {
        /// Server reported a Timeout while waiting for APDU Response.
        case timeoutWhileWaitingForResponse
        /// Server reported a Timeout while waiting for StartMesage.
        case timeoutWhileWaitingForStartMessage
        /// Max Session Time exceeded.
        case maxSessionTimeExceeded
        /// Unexpected Message was sent to the server.
        case unexpectedMessage
        /// Invalid Start Message.
        case invalidStartMessage
        /// Access Control failed. Ensure that the Access Key Values (MRZ information or CAN) are correct and try again.
        case accessControlFailed
        /// WebSocket communication with the Server failed.
        /// The associated error was either thrown by the [send](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask/3281790-send)
        /// or [receive](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask/3281789-receive) method of an
        /// [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask).
        /// Or the method [urlSession(_, task:, didCompleteWithError:)](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411610-urlsession)  
        /// of the [URLSessionTaskDelegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate) was called.
        case communicationFailed(Error?)
        /// Server reported that a file could not be read.
        case fileReadError
        /// An Exception in the eMRTD Server implementation occurred.
        case emrtdPassportReaderError
        /// Unexpected other Server Error.
        case serverError
        /// DocVal Server was not able to post the Result to the Result-Server.
        case postToResultServerFailed
        /// The provided Client ID is not correct.
        case invalidClientId
        /// The Access Key values are invalid.
        /// Ensure that the CAN consists of 6 digits (0-9).
        /// Ensure that the Document Number is at least 8 characters long.
        /// Ensure the Date of Birth and Date of Expiry are 6 digits in format yyMMdd (as in the MRZ).
        case invalidAccessKeyValues
        /// Communicating with the NFC Chip failed.
        /// The most likely reason is that the passport was moved away from the phone.
        /// The associated error is the error thrown by the [NFCISO7816Tag.sendcommandapdu](https://developer.apple.com/documentation/corenfc/nfciso7816tag/3043835-sendcommand) method.
        case nfcChipCommunicationFailed(Error?)
        /// Fallback if the Close Reason String from the DocVal Server has an unexpected Value.
        case other(reasonPhrase: String?)

        static func get(reasonPhrase: String?,
                        nfcError: Error?,
                        websocketError: Error?) -> CloseReason? {
            if reasonPhrase == nil || reasonPhrase?.isEmpty == true {
                return nil
            }
            let dict: [String?: CloseReason] = [
                CloseReasonRaw.timeoutWhileWaitingForResponse: .timeoutWhileWaitingForResponse,
                CloseReasonRaw.timeoutWhileWaitingForStartMessage: .timeoutWhileWaitingForStartMessage,
                CloseReasonRaw.maxSessionTimeExceeded: .maxSessionTimeExceeded,
                CloseReasonRaw.unexpectedMessage: .unexpectedMessage,
                CloseReasonRaw.invalidStartMessage: .invalidStartMessage,
                CloseReasonRaw.accessControlFailed: .accessControlFailed,
                CloseReasonRaw.communicationFailed: .communicationFailed(websocketError),
                CloseReasonRaw.fileReadError: .fileReadError,
                CloseReasonRaw.emrtdPassportReaderError: .emrtdPassportReaderError,
                CloseReasonRaw.serverError: .serverError,
                CloseReasonRaw.postToResultServerFailed: .postToResultServerFailed,
                CloseReasonRaw.invalidClientId: .invalidClientId,
                CloseReasonRaw.invalidAccessKeyValues: .invalidAccessKeyValues,
                CloseReasonRaw.nfcChipCommunicationFailed: .nfcChipCommunicationFailed(nfcError),
                nil: .other(reasonPhrase: nil)
            ]
            return dict[reasonPhrase] ?? .other(reasonPhrase: reasonPhrase)
        }

        /// Human Readable description of the CloseReason case
        public var description: String {
            switch self {
            case .timeoutWhileWaitingForResponse:
                return "Server reported Timeout while waiting for APDU Response"
            case .timeoutWhileWaitingForStartMessage:
                return "Server Reported Timeout while waiting for StartMesage"
            case .maxSessionTimeExceeded:
                return "Max Session Time exceeded"
            case .unexpectedMessage:
                return "Unexpected Message was sent to the server"
            case .invalidStartMessage:
                return "Invalid Start Message"
            case .accessControlFailed:
                return "Access Control failed"
            case .communicationFailed(error: let e):
                return describeOptionalError("Server Communication Failed", error: e)
            case .fileReadError:
                return "Error occurred while reading a file"
            case .emrtdPassportReaderError:
                return "Passport-Reader Error occurred"
            case .serverError:
                return "Server error"
            case .postToResultServerFailed:
                return "Post to ResultServer failed"
            case .invalidClientId:
                return "Invalid Client ID"
            case .invalidAccessKeyValues:
                return "Invalid Access Key Values"
            case .nfcChipCommunicationFailed(error: let e):
                return describeOptionalError("NFC Chip Communication Failed", error: e)
            case .other(reasonPhrase: let reasonPhrase):
                return reasonPhrase ?? "Unknwon Close Reason"
            }
        }

        private func describeOptionalError(_ text: String, error: Error?) -> String {
            if let error = error {
                return text + "\n" + error.localizedDescription
            }
            return text
        }
    }
}
