//
//  ASN1.swift
//  NFCPassportReader
//
//  Created by Tim Vogel on 16.03.20.
//

enum ASN1Error: Error {
    case failedToDecodeLength(String)
    case failedToReadValue(String)
    case failedToDecodeTagNumber(String)
    case failedToEncodeLength(Int)
    case failedToDecodeObjectIdentifier(String)

    var monitoringText: String {
        let text: String
        switch self {
        case .failedToDecodeLength(let additionalText):
            text = "Failed to decode length\n\(additionalText)"
        case .failedToReadValue(let additionalText):
            text = "Failed to read value\n\(additionalText)"
        case .failedToDecodeTagNumber(let additionalText):
            text = "Failed to decode TagNumber\n\(additionalText)"
        case .failedToEncodeLength(let length):
            text = "Failed to encode Length\n\(length)"
        case .failedToDecodeObjectIdentifier(let additionalText):
            text = "Failed to decode ObjectIdentifier\n\(additionalText)"
        }
        return "ASN1Error: \(text)"
    }
}

enum ASN1TagClass: UInt8 {
    case universal = 0x00
    case application = 0x01
    case contextSpecific = 0x02
    case privateClass = 0x03
    case unknown = 0xFF
}

enum ASN1TagNumber: UInt64 {
    case integer = 0x02
    case octetString = 0x04
    case objectIdentifier = 0x06
    case sequence = 0x10
    case set = 0x11
}

struct ASN1Tag: Equatable, CustomDebugStringConvertible, Hashable {
    static let Integer: [UInt8] = [0x02]
    static let OctedString: [UInt8] = [0x04]
    static let ObjectIdentifier: [UInt8] = [0x06]
    static let Sequence: [UInt8] = [0x30]
    static let Set: [UInt8] = [0x31]

    public let cls: ASN1TagClass
    public let primitive: Bool
    public let number: UInt64
    public var constructed: Bool { !primitive }
    public let rawBytes: ArraySlice<UInt8>

    fileprivate init(cls: ASN1TagClass, primitive: Bool, number: UInt64, rawBytes: ArraySlice<UInt8>) {
        self.cls = cls
        self.primitive = primitive
        self.number = number
        self.rawBytes = rawBytes
    }

    fileprivate init(cls: ASN1TagClass, primitive: Bool, number: ASN1TagNumber, rawBytes: ArraySlice<UInt8>) {
        self.init(cls: cls, primitive: primitive, number: number.rawValue, rawBytes: rawBytes)
    }

    static func == (lhs: ASN1Tag, rhs: ASN1Tag) -> Bool {
        lhs.cls == rhs.cls && lhs.primitive == rhs.primitive && lhs.number == rhs.number
    }

    static func == (lhs: ASN1Tag, rhs: [UInt8]) -> Bool {
        lhs == (try? ASN1.nextTag(data: rhs))?.tag
    }

    var debugDescription: String {
        "ASN1TAG - Class: \(cls), " + (primitive ? "primitive" : "constructed") + ", TagNumber: \(number)"
    }
}

// swiftlint:disable:next large_tuple
typealias ASN1TLV = (
    rawBytes: ArraySlice<UInt8>,
    tag: ASN1Tag,
    length: Int,
    value: ArraySlice<UInt8>
)

struct ASN1Integer: Hashable {
    let rawBytes: [UInt8]
    let int: Int64?

    init(bytes: [UInt8]) {
        self.rawBytes = bytes
        if bytes.count <= 8 && !bytes.isEmpty {
            var value: Int64 = 0
            let negative = bytes[0] >> 7 & 0x01 == 0x01
            if negative {
                value = ~value
            }

            var readIndex = 0
            while readIndex < bytes.count {
                value = value << 8
                value |= Int64(bytes[readIndex])
                readIndex += 1
            }
            self.int = value
        } else {
            self.int = nil
        }
    }
}

struct ASN1ObjectIdentifier: Hashable {
    let rawBytes: [UInt8]
    let string: String

    init(bytes: [UInt8]) throws {
        self.rawBytes = bytes

        var readIndex = 0
        let firstByte = bytes[readIndex]
        readIndex += 1

        var nodes = [UInt64(firstByte / 40), UInt64(firstByte % 40)]
        while readIndex < bytes.endIndex {
            var nextNode: UInt64 = 0
            repeat {
                guard readIndex < bytes.endIndex else {
                    throw ASN1Error.failedToDecodeObjectIdentifier("Index out of bounds")
                }
                nextNode = nextNode << 7
                nextNode |= UInt64(bytes[readIndex] & 0b0111_1111)
                readIndex += 1
            } while bytes[readIndex - 1] & 0b1000_0000 == 0b1000_0000
            nodes.append(nextNode)
        }
        string = nodes.map { String($0) }.joined(separator: ".")
    }
}

// DOC9303 Part 10 Chapter 4.3
// The implementation in DataGroupParser.swift has bugs (e.g. getNextTag() method)
// Therefore i want to provide a clean new implementation with less bugs and less magic constants
enum ASN1 {
    static func nextTag(data: [UInt8]) throws -> (tag: ASN1Tag, remaining: ArraySlice<UInt8>) {
        try nextTag(data: data[0...])
    }

    static func nextTag(data: ArraySlice<UInt8>) throws -> (tag: ASN1Tag, remaining: ArraySlice<UInt8>) {
        var readIndex = data.startIndex
        guard readIndex < data.endIndex else {
            throw ASN1Error.failedToDecodeTagNumber("Index out of bounds")
        }
        let firstByte = data[readIndex]
        readIndex += 1

        // Read the tag
        let tagClass = ASN1TagClass(rawValue: (firstByte >> 6 & 0b11)) ?? .unknown
        let tagIsPrimitive = (firstByte >> 5 & 1) == 0
        var tagNumber = UInt64(firstByte & 0b0001_1111)
        if tagNumber == 0b0001_1111 {
            // Special case: The tag number is encoded in the following bytes
            tagNumber = 0
            repeat {
                guard readIndex < data.endIndex else {
                    throw ASN1Error.failedToDecodeTagNumber("Index out of bounds")
                }
                tagNumber = tagNumber << 7
                tagNumber |= UInt64(data[readIndex] & 0b0111_1111)
                readIndex += 1
            } while data[readIndex - 1] & 0b1000_0000 == 0b1000_0000
        }

        let rawBytes = data[data.startIndex..<readIndex]
        let remaining = data[readIndex...]
        let tag = ASN1Tag(cls: tagClass, primitive: tagIsPrimitive, number: tagNumber, rawBytes: rawBytes)
        return (tag: tag, remaining: remaining)
    }

    static func nextLength(data: ArraySlice<UInt8>) throws -> (length: Int, remaining: ArraySlice<UInt8>) {
        var readIndex = data.startIndex
        func checkRange(index: Int) throws {
            guard index < data.endIndex else {
                throw ASN1Error.failedToDecodeLength("Index out of range")
            }
        }

        try checkRange(index: readIndex)
        // Read the length of the value
        var length = 0
        let firstLengthByte = data[readIndex]
        readIndex += 1
        switch firstLengthByte {
        case _ where firstLengthByte < 0x7F:
            length = Int(firstLengthByte)
        case 0x81:
            try checkRange(index: readIndex)
            length = Int(data[readIndex])
            readIndex += 1
        case 0x82:
            try checkRange(index: readIndex + 1)
            length = Int(data[readIndex]) << 8 | Int(data[readIndex + 1])
            readIndex += 2
        case 0x83:
            try checkRange(index: readIndex + 2)
            length = Int(data[readIndex]) << 16 | Int(data[readIndex + 1]) << 8 | Int(data[readIndex + 2])
            readIndex += 3
        case 0x84:
            try checkRange(index: readIndex + 3)
            length = Int(data[readIndex]) << 24 | Int(data[readIndex + 1]) << 16 | Int(data[readIndex + 2]) << 8 | Int(data[readIndex + 3])
            readIndex += 4
        default:
            throw ASN1Error.failedToDecodeLength("Invalid first byte \(firstLengthByte)")
        }

        return (length: length, remaining: data[readIndex...])
    }

    static func nextValue(data: ArraySlice<UInt8>, length: Int) throws -> (value: ArraySlice<UInt8>, remaining: ArraySlice<UInt8>) {
        let valueEndIndex = data.startIndex + length
        guard valueEndIndex <= data.endIndex else {
            throw ASN1Error.failedToReadValue("Index out of range")
        }
        return (value: data[data.startIndex..<valueEndIndex], remaining: data[valueEndIndex...])
    }

    static func nextTagLengthValue(data: [UInt8]) throws -> (tlv: ASN1TLV, remaining: ArraySlice<UInt8>) {
        try nextTagLengthValue(data: data[0...])
    }

    static func nextTagLengthValue(data: ArraySlice<UInt8>) throws -> (tlv: ASN1TLV, remaining: ArraySlice<UInt8>) {
        let startIndex = data.startIndex
        var remaining = data
        let tag: ASN1Tag
        let length: Int
        let value: ArraySlice<UInt8>

        (tag, remaining) = try nextTag(data: remaining)
        (length, remaining) = try nextLength(data: remaining)
        (value, remaining) = try nextValue(data: remaining, length: length)

        let rawBytes = data[startIndex..<remaining.startIndex]
        let tlv = ASN1TLV(rawBytes: rawBytes, tag: tag, length: length, value: value)
        return (tlv: tlv, remaining: remaining)
    }

    static func readObjectIdentifierValue(tlv oi: ASN1TLV?) -> ASN1ObjectIdentifier? {
        guard let oi = oi, oi.tag == ASN1Tag.ObjectIdentifier else {
            return nil
        }
        return try? ASN1ObjectIdentifier(bytes: Array(oi.value))
    }

    static func readInteger(tlv int: ASN1TLV?) -> ASN1Integer? {
        guard let int = int, int.tag == ASN1Tag.Integer else {
            return nil
        }
        return ASN1Integer(bytes: Array(int.value))
    }
}

extension ASN1 {
    static func toASN1Length(length: Int) -> [UInt8] {
        if length <= 0x7F {
            return [UInt8(length)]
        } else {
            let importantBytesCount = (length.bitWidth / 8) - (length.leadingZeroBitCount / 8)
            var asn1Length: [UInt8] = [0x80 + UInt8(importantBytesCount)]
            for i in stride(from: importantBytesCount, to: 0, by: -1) {
                asn1Length.append(UInt8((length >> (8 * (i - 1))) & 0xFF))
            }
            return asn1Length
        }
    }

    static func pack(tag: [UInt8], value: [UInt8]) -> [UInt8] {
        tag + toASN1Length(length: value.count) + value
    }
}
