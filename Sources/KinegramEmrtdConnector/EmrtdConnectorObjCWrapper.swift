//
//  EmrtdConnectorObjCWrapper.swift
//  Kinegram eMRTD Connector
//
//  Created by Alexander Manzer on 10.12.24.
//

import Foundation
import CoreNFC

@objc public class EmrtdConnectorObjCWrapper: NSObject {
    private var connector: EmrtdConnector?
    private var session: NFCTagReaderSession?
    private var completionCallback: ((String?, Error?) -> Void)?
    private var documentNumber: String?
    private var dateOfBirth: String?
    private var dateOfExpiry: String?
    private var can: String?

    private let errorDomain = "io.kinegram.emrtd"

    @objc public init?(clientId: String, webSocketUrl: String) {
        super.init()
        connector = EmrtdConnector(clientId: clientId, webSocketUrl: webSocketUrl, delegate: self)
        if connector == nil {
            return nil
        }
    }

    @objc public func readPassport(documentNumber: String,
                                   dateOfBirth: String,
                                   dateOfExpiry: String,
                                   completion: @escaping (String?, Error?) -> Void) {

        guard handleNFCAvailability(completion: completion) else {
            return
        }

        self.documentNumber = documentNumber
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
        self.can = nil
        self.completionCallback = completion

        startNFCSession()
    }

    @objc public func readPassport(can: String,
                                   completion: @escaping (String?, Error?) -> Void) {

        guard handleNFCAvailability(completion: completion) else {
            return
        }

        self.can = can
        self.documentNumber = nil
        self.dateOfBirth = nil
        self.dateOfExpiry = nil
        self.completionCallback = completion

        startNFCSession()
    }

    private func startNFCSession() {
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main)
        session?.alertMessage = "Place the top of your phone on the document\n"
        session?.begin()
    }

    private func handleNFCAvailability(completion: (String?, Error?) -> Void) -> Bool {
        guard NFCTagReaderSession.readingAvailable else {
            let error = NSError(domain: errorDomain,
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "NFC not available"])
            completion(nil, error)
            return false
        }
        return true
    }
}

// MARK: - NFCTagReaderSessionDelegate
extension EmrtdConnectorObjCWrapper: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // nothing to be done here...
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first,
              case let .iso7816(iso7816Tag) = tag else {
            session.invalidate(errorMessage: "Invalid tag")
            return
        }

        if let can = can {
            connector?.connect(to: iso7816Tag,
                               vId: UUID().uuidString,
                               can: can)
        } else if let documentNumber = documentNumber,
                  let dateOfBirth = dateOfBirth,
                  let dateOfExpiry = dateOfExpiry {
            connector?.connect(to: iso7816Tag,
                               vId: UUID().uuidString,
                               documentNumber: documentNumber,
                               dateOfBirth: dateOfBirth,
                               dateOfExpiry: dateOfExpiry)
        } else {
            session.invalidate(errorMessage: "Missing credentials")
        }
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        completionCallback?(nil, error)
    }
}

// MARK: - EmrtdConnectorDelegate
extension EmrtdConnectorObjCWrapper: EmrtdConnectorDelegate {
    public func shouldRequestEmrtdPassport() -> Bool {
        return true
    }

    public func emrtdConnector(_ connector: EmrtdConnector, didUpdateStatus status: EmrtdConnector.Status) {
        // Update NFC session alert message based on status
        switch status {
        case .connectingToServer:
            session?.alertMessage = "Hold still\n"
        case .accessControl:
            session?.alertMessage = "Reading data from chip\n▮▯▯▯▯▯▯"
        case .readSOD:
            session?.alertMessage = "Reading data from chip\n▮▮▯▯▯▯▯"
        case .chipAuthentication, .activeAuthentication, .readDG1:
            session?.alertMessage = "Reading data from chip\n▮▮▮▯▯▯▯"
        case .readDG2:
            session?.alertMessage = "Reading data from chip\n▮▮▮▮▯▯▯"
        case .readDG7, .readDG11, .readDG12, .passiveAuthentication:
            session?.alertMessage = "Verifying\n▮▮▮▮▮▮▯"
        case .done:
            session?.alertMessage = "Done\n▮▮▮▮▮▮▮"
        default:
            break
        }
    }

    public func emrtdConnector(_ connector: EmrtdConnector, didReceiveEmrtdPassport passport: EmrtdPassport?) {
        if let passport = passport {
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(passport),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                completionCallback?(jsonString, nil)
            } else {
                completionCallback?(nil, NSError(domain: errorDomain,
                                                 code: 3,
                                                 userInfo: [NSLocalizedDescriptionKey: "Failed to encode passport data"]))
            }
        } else {
            completionCallback?(nil, NSError(domain: errorDomain,
                                             code: 2,
                                             userInfo: [NSLocalizedDescriptionKey: "No passport data received"]))
        }
    }

    public func emrtdConnector(_ connector: EmrtdConnector, didCloseWithCloseCode closeCode: Int, reason: EmrtdConnector.CloseReason?) {
        if closeCode != 1000 {
            session?.invalidate(errorMessage: reason?.description ?? "Unknown error")
            let error = NSError(domain: errorDomain,
                                code: closeCode,
                                userInfo: [NSLocalizedDescriptionKey: reason?.description ?? "Unknown error"])
            completionCallback?(nil, error)
        }

        // Clean up
        session = nil
        completionCallback = nil
        documentNumber = nil
        dateOfBirth = nil
        dateOfExpiry = nil
        can = nil
    }
}
