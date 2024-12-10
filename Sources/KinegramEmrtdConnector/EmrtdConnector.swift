//
//  EmrtdConnector.swift
//  kinegram_emrtd_connector
//
//  Created by Tim Vogel on 04.01.22.
//

import CoreNFC

///
/// Connect an eMRTD NFC Chip with the Document Validation Server.
///
/// Will connect to the NFC Chip using an [NFCISO7816Tag](https://developer.apple.com/documentation/corenfc/nfciso7816tag).
/// WIll connect to the Document Validation Server using an [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask).
///
public class EmrtdConnector {
    private static let retQuery = "return_result=true"
    private let clientId: String
    private let url: URL
    private weak var delegate: EmrtdConnectorDelegate?
    private weak var webSocketSessionDelegate: WebSocketSessionDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var nfcError: Error?
    private var websocketError: Error?

    ///
    /// - Parameters:
    ///     - clientId: Client Id
    ///     - webSocketUrl: Url of the WebSocket endpoint
    ///     - delegate: EmrtdConnectorDelegate
    ///
    /// - Returns: A newly initialized EmrtdConnector; otherwise, nil if the webSocketUrl is an invalid string.
    public init?(clientId: String,
                 webSocketUrl url: String,
                 delegate: EmrtdConnectorDelegate) {
        let shouldRequestEmrtdPassport = delegate.shouldRequestEmrtdPassport()

        var query = ""
        if shouldRequestEmrtdPassport && !url.contains(EmrtdConnector.retQuery) {
            query = url.contains("?") ? "&" : "?" + EmrtdConnector.retQuery
        }
        guard let u = URL(string: url + query) else {
            return nil
        }
        self.url = u
        self.clientId = clientId
        self.delegate = delegate
    }

    ///
    /// Starts the Session.
    ///
    /// The `documentNumber`, `dateOfBirth`, `dateOfExpiry` function as the Access Key, 
    /// required to access the chip.
    ///
    /// - Parameters:
    ///   - passportTag: NFCISO7816Tag acquired from iOS
    ///   - vId: Unique String to identify this session
    ///   - documentNumber: Document Number from the MRZ.
    ///   - dateOfBirth: Date of Birth from the MRZ (Format: yyMMdd)
    ///   - dateOfExpiry: Date of Expiry from the MRZ (Format: yyMMdd)
    public func connect(to passportTag: NFCISO7816Tag,
                        vId: String,
                        documentNumber: String,
                        dateOfBirth: String,
                        dateOfExpiry: String) {
        let key = [
            "document_number": documentNumber,
            "date_of_birth": dateOfBirth,
            "date_of_expiry": dateOfExpiry
        ]
        let startMsg = StartMessage(clientId: clientId, validationId: vId, accessKey: key)
        connect(passportTag: passportTag, startMessage: startMsg)
    }

    ///
    /// Starts the Session.
    ///
    /// The `can` functions as the Access Key and is required to access the chip.
    ///
    /// - Parameters:
    ///   - passportTag: NFCISO7816Tag acquired from iOS
    ///   - vId: Unique String to identify this session.
    ///   - can: CAN, a 6 digit number, printed on the front of the document.
    public func connect(to passportTag: NFCISO7816Tag, vId: String, can: String) {
        let key = ["can": can]
        let startMsg = StartMessage(clientId: clientId, validationId: vId, accessKey: key)
        connect(passportTag: passportTag, startMessage: startMsg)
    }

    ///
    /// Check if a session is currently open
    ///
    /// - Returns: true if the session is open
    public func isOpen() -> Bool {
        webSocketSessionDelegate != nil && webSocketTask?.state == .running
    }

    private func connect(passportTag: NFCISO7816Tag, startMessage: StartMessage) {
        websocketError = nil
        nfcError = nil

        let webSocketSessionDelegate = WebSocketSessionDelegate { closeCode, reasonPhrase, websocketError in
            guard self.webSocketSessionDelegate != nil, self.webSocketTask != nil else {
                return
            }
            self.webSocketSessionDelegate = nil
            self.webSocketTask = nil
            let closeReason = CloseReason.get(reasonPhrase: reasonPhrase,
                                              nfcError: self.nfcError,
                                              websocketError: websocketError ?? self.websocketError)
            self.delegate?.emrtdConnector(self, didCloseWithCloseCode: closeCode, reason: closeReason)
            if closeCode != 1_000 {
                passportTag.session?.invalidate(errorMessage: "")
            } else {
                passportTag.session?.invalidate()
            }
        }
        self.webSocketSessionDelegate = webSocketSessionDelegate

        let config: URLSessionConfiguration = .ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 120
        var request = URLRequest(url: url)
        request.networkServiceType = .responsiveData
        let webSocketTask = URLSession(configuration: config, delegate: webSocketSessionDelegate, delegateQueue: .main)
            .webSocketTask(with: request)
        self.webSocketTask = webSocketTask
        webSocketTask.resume()

        delegate?.emrtdConnector(self, didUpdateStatus: .readAtrInfo)

        EmrtdChipCommunicationSession(nfcTag: passportTag).readAtrInfo { atrInfoFile in
            self.delegate?.emrtdConnector(self, didUpdateStatus: .connectingToServer)

            var startMessage = startMessage
            startMessage.maxCommandBytes = atrInfoFile?.maxCommandBytes
            startMessage.maxResponseBytes = atrInfoFile?.maxResponseBytes

            webSocketTask.send(.string(startMessage.asJsonString())) { error in
                guard error == nil else {
                    self.websocketError = error
                    self.closeWebSocket(reason: CloseReasonRaw.communicationFailed)
                    return
                }
                self.readMessage(passportTag: passportTag)
            }
        }
    }

    private func readMessage(passportTag: NFCISO7816Tag) {
        webSocketTask?.receive { result in
            switch result {
            case .failure(let error):
                self.websocketError = error
                self.closeWebSocket(reason: CloseReasonRaw.communicationFailed)

            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(passportTag: passportTag, text: text)
                case .data(let data):
                    self.handleBinaryMessage(passportTag: passportTag, data: data)
                @unknown default:
                    print("Unexpected Message type")
                }
                self.readMessage(passportTag: passportTag)
            }
        }
    }

    private func handleTextMessage(passportTag: NFCISO7816Tag, text: String) {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let dictionary = json as? [String: Any] {

            let status = Status.get(status: dictionary["status"] as? String)
            if let status = status {
                self.delegate?.emrtdConnector(self, didUpdateStatus: status)
                // NFC Session is done
                if case .done = status {
                    passportTag.session?.invalidate()
                }
            }

            let emrtdPassportDict = dictionary["emrtd_passport"] as? [String: Any]
            if emrtdPassportDict != nil, let data = text.data(using: .utf8) {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let type = TextMessageFromServer.self
                if let emrtdPassport = try? decoder.decode(type, from: data).emrtdPassport {
                    self.delegate?.emrtdConnector(self, didReceiveEmrtdPassport: emrtdPassport)
                } else {
                    print("Failed to decode EmrtdPassport")
                    self.delegate?.emrtdConnector(self, didReceiveEmrtdPassport: nil)
                }
            }

            let closeCode = dictionary["close_code"] as? Int
            if let closeCode = closeCode {
                let closeReason = dictionary["close_reason"] as? String
                self.webSocketSessionDelegate?.closedListener(closeCode, closeReason, nil)
            }

            if status == nil && emrtdPassportDict == nil && closeCode == nil {
                print("Received Unexpected text message: \(text)")
            }
        } else {
            print("Failed to parse Text Message")
        }
    }

    private func handleBinaryMessage(passportTag: NFCISO7816Tag, data: Data) {
        guard let commandApdu = NFCISO7816APDU(data: data) else {
            closeWebSocket(reason: CloseReasonRaw.nfcChipCommunicationFailed)
            return
        }

        passportTag.sendCommand(apdu: commandApdu) { data, sw1, sw2, error in
            guard let webSocketTask = self.webSocketTask else {
                return
            }
            guard error == nil else {
                self.nfcError = error
                self.closeWebSocket(reason: CloseReasonRaw.nfcChipCommunicationFailed)
                return
            }
            webSocketTask.send(.data(data + [sw1, sw2])) { error in
                guard error == nil else {
                    self.websocketError = error
                    self.closeWebSocket(reason: CloseReasonRaw.communicationFailed)
                    return
                }
            }
        }
    }

    private func closeWebSocket(reason reasonPhrase: String) {
        let closeCode = URLSessionWebSocketTask.CloseCode.goingAway
        webSocketTask?.cancel(with: closeCode, reason: reasonPhrase.data(using: .utf8))
    }

    private class WebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate {
        let closedListener: ((Int, String?, Error?) -> Void)

        init(closedListener: @escaping (Int, String?, Error?) -> Void) {
            self.closedListener = closedListener
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            let closeCode = URLSessionWebSocketTask.CloseCode.abnormalClosure
            closedListener(closeCode.rawValue, CloseReasonRaw.communicationFailed, error)
        }

        func urlSession(_ session: URLSession,
                        webSocketTask: URLSessionWebSocketTask,
                        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                        reason: Data?) {
            if let reason = reason {
                closedListener(closeCode.rawValue, String(data: reason, encoding: .utf8), nil)
            } else {
                closedListener(closeCode.rawValue, nil, nil)
            }
        }
    }
}
