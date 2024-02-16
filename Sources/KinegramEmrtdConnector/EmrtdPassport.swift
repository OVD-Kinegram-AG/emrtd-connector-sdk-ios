//
//  EmrtdPassport.swift
//  kinegram_emrtd_connector
//
//  Created by Tim Vogel on 13.01.22.
//

import Foundation

struct TextMessageFromServer: Codable, Hashable {
    let emrtdPassport: EmrtdPassport
}

///
/// Holds the results returned by the Document Validation Server.
///
/// It directly represents the `emrtd_passport` JSON Object returned by the Document Validation
/// Server. Refer to the DocVal server documentation for details.
///
public struct EmrtdPassport: Codable, Hashable, CustomStringConvertible {
    public let sodInfo: SODInfo?
    public let mrzInfo: MRZInfo?
    public let facePhoto: Data?
    public let signaturePhotos: [Data]?
    public let additionalPersonalDetails: AdditionalPersonalDetails?
    public let additionalDocumentDetails: AdditionalDocumentDetails?

    public let passiveAuthentication: Bool
    public let passiveAuthenticationDetails: PassiveAuthenticationDetails?
    public let chipAuthenticationResult: CheckResult
    public let activeAuthenticationResult: CheckResult

    public let errors: [String]

    /// The files (SOD and DataGroups) in raw binary format.
    /// This field is optional. It will only be set if the Document Validation Service is configured to include this 
    /// field in the response.
    public let filesBinary: [String: Data]?

    public var description: String {
        func describeStruct(_ any: Any?) -> String {
            guard let any = any else {
                return "nil"
            }
            let s = String(describing: any)
            if let index = s.firstIndex(of: "\n") {
                return String(s[index...]).replacingOccurrences(of: "\n\t", with: "\n\t\t")
            }
            return s
        }
        var description =
            """
            EmrtdPassport:
            \tsodInfo: \(describeStruct(sodInfo))
            \tmrzInfo: \(describeStruct(mrzInfo))
            \tfacePhoto: \(EmrtdPassport.describe(facePhoto))
            \tsignaturePhotos: \(EmrtdPassport.describe(signaturePhotos))
            \tadditionalPersonalDetails: \(describeStruct(additionalPersonalDetails))
            \tadditionalDocumentDetails: \(describeStruct(additionalDocumentDetails))
            \tpassiveAuthentication: \(passiveAuthentication)
            \tpassiveAuthenticationDetails: \(describeStruct(passiveAuthenticationDetails))
            \tactiveAuthenticationResult: \(activeAuthenticationResult)
            \tchipAuthenticationResult: \(chipAuthenticationResult)
            \terrors: \(errors)
            """
        if let filesBinary = filesBinary {
            description += "\n\tfilesBinary: \(filesBinary)"
        }
        return description
    }

    public struct SODInfo: Codable, Hashable, CustomStringConvertible {
        public let hashAlgorithm: String
        public let hashForDataGroup: [Int: String]

        public var description: String {
            var hashForDataGroup: String = ""
            for (dg, value) in self.hashForDataGroup {
                hashForDataGroup += "\n\t\t\(dg): \(value)"
            }
            return
                """
                SODInfo:
                \thashAlgorithm: \(describe(hashAlgorithm))
                \thashForDataGroup: \(hashForDataGroup)
                """
        }
    }

    public struct MRZInfo: Codable, Hashable, CustomStringConvertible {
        public let documentType: String
        public let documentCode: String
        public let issuingState: String
        public let primaryIdentifier: String
        public let secondaryIdentifier: [String]
        public let nationality: String
        public let documentNumber: String
        public let dateOfBirth: String
        public let dateOfExpiry: String
        public let gender: String
        public let optionalData1: String
        public let optionalData2: String?

        public var description: String {
            """
            MRZInfo:
            \tdocumentType: \(describe(documentType))
            \tdocumentCode: \(describe(documentCode))
            \tissuingState: \(describe(issuingState))
            \tprimaryIdentifier: \(describe(primaryIdentifier))
            \tsecondaryIdentifier: \(describe(secondaryIdentifier))
            \tnationality: \(describe(nationality))
            \tdocumentNumber: \(describe(documentNumber))
            \tdateOfBirth: \(describe(dateOfBirth))
            \tdateOfExpiry: \(describe(dateOfExpiry))
            \tgender: \(describe(gender))
            \toptionalData1: \(describe(optionalData1))
            \toptionalData2: \(describe(describe(optionalData2)))
            """
        }
    }

    public struct AdditionalPersonalDetails: Codable, Hashable, CustomStringConvertible {
        public let fullNameOfHolder: String?
        public let otherNames: [String]?
        public let personalNumber: String?
        public let fullDateOfBirth: String?
        public let placeOfBirth: String?
        public let permanentAddress: [String]?
        public let telephone: String?
        public let profession: String?
        public let title: String?
        public let personalSummary: String?
        public let proofOfCitizenshipImage: Data?
        public let otherValidTravelDocumentNumbers: [String]?
        public let custodyInformation: String?

        public var description: String {
            """
            AdditionalPersonalDetails:
            \tfullNameOfHolder: \(describe(fullNameOfHolder))
            \totherNames: \(describe(otherNames))
            \tpersonalNumber: \(describe(personalNumber))
            \tfullDateOfBirth: \(describe(fullDateOfBirth))
            \tplaceOfBirth: \(describe(placeOfBirth))
            \tpermanentAddress: \(describe(permanentAddress))
            \ttelephone: \(describe(telephone))
            \tprofession: \(describe(profession))
            \ttitle: \(describe(title))
            \tpersonalSummary: \(describe(personalSummary))
            \tproofOfCitizenshipImage: \(describe(proofOfCitizenshipImage))
            \totherValidTravelDocumentNumbers: \(describe(otherValidTravelDocumentNumbers))
            \tcustodyInformation: \(describe(custodyInformation))
            """
        }
    }

    public struct AdditionalDocumentDetails: Codable, Hashable, CustomStringConvertible {
        public let issuingAuthority: String?
        public let dateOfIssue: String?
        public let namesOfOtherPersons: String?
        public let endorsementsAndObservations: String?
        public let taxOrExitRequirements: String?
        public let imageOfFront: Data?
        public let imageOfRear: Data?
        public let dateAndTimeOfPersonalization: String?
        public let personalizationSystemSerialNumber: String?

        public var description: String {
            """
            AdditionalDocumentDetails:
            \tissuingAuthority: \(describe(issuingAuthority))
            \tdateOfIssue: \(describe(dateOfIssue))
            \tnamesOfOtherPersons: \(describe(namesOfOtherPersons))
            \tendorsementsAndObservations: \(describe(endorsementsAndObservations))
            \ttaxOrExitRequirements: \(describe(taxOrExitRequirements))
            \timageOfFront: \(describe(imageOfFront))
            \timageOfRear: \(describe(imageOfRear))
            \tdateAndTimeOfPersonalization: \(describe(dateAndTimeOfPersonalization))
            \tpersonalizationSystemSerialNumber: \(describe(personalizationSystemSerialNumber))
            """
        }
    }

    public struct PassiveAuthenticationDetails: Codable, Hashable, CustomStringConvertible {
        public let sodSignatureValid: Bool?
        public let documentCertificateValid: Bool?
        public let dataGroupsChecked: [Int]?
        public let dataGroupsWithValidHash: [Int]?
        public let allHashesValid: Bool?
        public let error: String?

        public var description: String {
            """
            PassiveAuthenticationDetails:
            \tsodSignatureValid: \(describe(sodSignatureValid))
            \tdocumentCertificateValid: \(describe(documentCertificateValid))
            \tdataGroupsChecked: \(describe(dataGroupsChecked))
            \tdataGroupsWithValidHash: \(describe(dataGroupsWithValidHash))
            \tallHashesValid: \(describe(allHashesValid))
            \terror: \(describe(error))
            """
        }
    }

    public enum CheckResult: String, Codable, Hashable, CustomStringConvertible {
        case success = "SUCCESS"
        case failed = "FAILED"
        case unavailable = "UNAVAILABLE"

        public var description: String {
            self.rawValue
        }
    }

    private static func describe(_ any: Any?) -> String {
        guard let any = any else {
            return "nil"
        }
        if let any = any as? String {
            return "\"\(any)\""
        }
        return String(describing: any)
    }
}
