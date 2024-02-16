//
//  AtrInfo.swift
//  NFCPassportReader
//
//  Created by Tim Vogel on 29.04.20.
//

///
/// AtrInfoFile representes the Elementary File ATR/INFO
///
/// Parses the file for *Extended length information*. See ISO 7816-4 for details.
///
class AtrInfoFile {
    /// The number of bytes in a command APDU shall not exceed this number.
    private(set) var maxCommandBytes: Int?
    /// Ne shall be set such that the number of bytes in a response APDU does not exceed this number.
    private(set) var maxResponseBytes: Int?

    init?(data: [UInt8]?) throws {
        guard let data = data else {
            return nil
        }
        var remaining = data[0...]
        while !remaining.isEmpty {
            let tlv: ASN1TLV
            (tlv, remaining) = try ASN1.nextTagLengthValue(data: remaining)
            if tlv.tag == [0x7F, 0x66] {
                let (maxCommandBytesTLV, remainingValue) = try ASN1.nextTagLengthValue(data: tlv.value)
                let (maxResponseBytesTLV, _) = try ASN1.nextTagLengthValue(data: remainingValue)
                if let maxCommandBytes = ASN1.readInteger(tlv: maxCommandBytesTLV)?.int,
                    let maxResponseBytes = ASN1.readInteger(tlv: maxResponseBytesTLV)?.int {
                    self.maxCommandBytes = Int(maxCommandBytes)
                    self.maxResponseBytes = Int(maxResponseBytes)
                }
                // We have got everything we need
                break
            }
        }
    }
}
