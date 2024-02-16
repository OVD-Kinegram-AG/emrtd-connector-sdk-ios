//
//  FileReader.swift
//  NFCPassportReader
//
//  Created by Tim Vogel on 10.03.20.
//

import CoreNFC

@available(iOS 13.0, *)
extension NFCISO7816APDU {
    fileprivate convenience init(insCls: UInt8, insCode: UInt8, p1: UInt8, p2: UInt8, data: Data = Data(), el: Int = -1) {
        self.init(instructionClass: insCls, instructionCode: insCode, p1Parameter: p1, p2Parameter: p2,
                  data: data, expectedResponseLength: el)
    }

    fileprivate convenience init(insCls: UInt8, insCode: UInt8, p1: UInt8, p2: UInt8, data: [UInt8], el: Int = -1) {
        self.init(insCls: insCls, insCode: insCode, p1: p1, p2: p2, data: Data(data), el: el)
    }
}

@available(iOS 13.0, *)
enum EmrtdChipCommunicationError: Error {
    case apduResponseError(sw1: UInt8, sw2: UInt8)
    case nfcReaderError(NFCReaderError)
    case unexpectedError(Error? = nil)
    case readBinaryOffsetTooLarge(totalFileSize: Int)
}

@available(iOS 13.0, *)
// swiftlint:disable:next large_tuple
typealias ResponseAPDU = (data: [UInt8], sw1: UInt8, sw2: UInt8)

@available(iOS 13.0, *)
class EmrtdChipCommunicationSession {
    typealias EmrtdResponseCallback = (ResponseAPDU?, EmrtdChipCommunicationError?) -> Void

    private let nfcTag: NFCISO7816Tag

    init(nfcTag: NFCISO7816Tag) {
        self.nfcTag = nfcTag
    }

    func selectMF(completed: @escaping EmrtdResponseCallback) {
        send(apduCommand: NFCISO7816APDU(insCls: 0, insCode: 0xA4, p1: 0x00, p2: 0x0C), completed: completed)
    }

    func readAtrInfo(onCompleted: @escaping (AtrInfoFile?) -> Void) {
        selectMF { _, _ in
            self.selectFileFromCurrentDF(fileId: [0x2F, 0x01]) { _, error in
                guard error == nil else {
                    onCompleted(nil)
                    return
                }
                self.readBinary(totalLength: 64, maxAtOnceReadBinaryLength: 1) { data, _ in
                    onCompleted(try? AtrInfoFile(data: data))
                }
            }
        }
    }

    private func selectFileFromCurrentDF(fileId: [UInt8], onCompleted: @escaping EmrtdResponseCallback) {
        let selectFileCommand = NFCISO7816APDU(insCls: 0, insCode: 0xA4, p1: 0x02, p2: 0x0C, data: fileId)
        send(apduCommand: selectFileCommand, completed: onCompleted)
    }

    ///
    /// Read binary data.
    /// Ensure that the file has already been selected!
    ///
    /// Uses Instruction `0xB0` read binary data.
    /// The offset will be encoded in 15 Bits
    /// This means, that a maximum offset of 32767 Bytes is possible (0b0111_1111_1111_1111).
    /// Resulting in a maximum of (32767 Bytes + `maxAtOnceReadBinaryLength` Bytes) that can be read.
    /// Larger files than that can not be read.
    ///
    private func readBinary(offset: UInt16 = 0,
                            totalLength: Int,
                            maxAtOnceReadBinaryLength: Int,
                            outData: [UInt8] = [UInt8](),
                            onCompleted: @escaping ([UInt8]?, EmrtdChipCommunicationError?) -> Void) {
        let readLength = min(maxAtOnceReadBinaryLength, totalLength - Int(offset))

        // With Instruction Code 0xB0 we can use 15 Bits to encode the offset
        if offset > 0b0111_1111_1111_1111 {
            // Unexpectedly large file...
            // A different implementation that uses Instruction Code 0xB1 should be used instead.
            onCompleted(outData, .readBinaryOffsetTooLarge(totalFileSize: totalLength))
            return
        }

        let p1 = UInt8(offset >> 8 & 0xFF)
        let p2 = UInt8(offset & 0xFF)

        // According to ISO 7816 the bit b8 of P1 must be `0`
        // The other 15 bits of P1 and P2 encode the offset.
        assert(p1 >> 7 & 0xFF == 0)

        let readBinaryCommand = NFCISO7816APDU(insCls: 0, insCode: 0xB0, p1: p1, p2: p2, el: readLength)

        send(apduCommand: readBinaryCommand) { response, error in
            guard let responseData = response?.data, error == nil else {
                onCompleted(outData, error)
                return
            }
            let outData = outData + responseData
            let offset = offset + UInt16(responseData.count)
            if offset < totalLength && !responseData.isEmpty {
                self.readBinary(offset: offset,
                                totalLength: totalLength,
                                maxAtOnceReadBinaryLength: maxAtOnceReadBinaryLength,
                                outData: outData,
                                onCompleted: onCompleted)
            } else {
                onCompleted(outData, nil)
            }
        }
    }

    private func send(apduCommand: NFCISO7816APDU, completed: @escaping EmrtdResponseCallback) {
        nfcTag.sendCommand(apdu: apduCommand) { data, sw1, sw2, error in
            guard error == nil else {
                if let nfcError = error as? NFCReaderError {
                    completed(nil, .nfcReaderError(nfcError))
                } else {
                    completed(nil, .unexpectedError(error))
                }
                return
            }

            let responseApdu = ResponseAPDU(data: Array(data), sw1: sw1, sw2: sw2)
            if sw1 == 0x90 && sw2 == 0x00 {
                completed(responseApdu, nil)
            } else if sw1 == 0x62 || sw1 == 0x63 {
                // let msg = String(format: "EmrtdChipCommuncation APDU Response Warning. Response: sw1 - 0x%02x, sw2 - 0x%02x", sw1, sw2)
                // TODO: LOG
                completed(responseApdu, nil)
            } else {
                // Log.error("EmrtdChipCommuncation APDU Command Failed. Response: sw1 - 0x\(binToHexRep(sw1)), sw2 - 0x\(binToHexRep(sw2))")
                completed(nil, .apduResponseError(sw1: sw1, sw2: sw2))
            }
        }
    }
}
