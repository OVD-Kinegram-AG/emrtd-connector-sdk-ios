//
//  kds_sdk_templateTests.swift
//  kds_sdk_templateTests
//
//  Created by Christian Braun on 23.12.21.
//

import XCTest
@testable import KinegramEmrtdConnector

class ParseEmrtdJSONTest: XCTestCase {
    private let testBundle = Bundle.init(for: ParseEmrtdJSONTest.self)
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func testDecodeEmrtdPassportParker() throws {
        let expected = EmrtdPassport(
            sodInfo: EmrtdPassport.SODInfo(
                hashAlgorithm: "SHA-256",
                hashForDataGroup: [
                    1: "B7ZYsPUdx6/77hON2QpI/7Hr36tlH5m+Am0WuzWDFn4=",
                    2: "b4xR1WNjbu5DY67seOpC8OAmkwErnwbsXkJIzTiCuas=",
                    7: "Rt0gaZ1pvAnp0CEcd+ir05fWCpT+cj7ecKxH+rWUDoo=",
                    11: "/oYfYTAHXtF5oZbb6kcMrq7BGoMVtmOWsqvM0ctyBCI=",
                    12: "IXIYTHM0l3EeCpu74Z1zHTGT1HQH1KRKU+2Dhu8OuRA=",
                    14: "w62EEvLa74fLyhBYiulDtrt/2vQmueFGAJM5s+UdtMM=",
                    15: "VjBncDBu+qGAcCoZFthMNuU3pmBR8ECLXejkKhjIM+A="
                ]
            ),
            mrzInfo: EmrtdPassport.MRZInfo(
                documentType: "TD3",
                documentCode: "P",
                issuingState: "USA",
                primaryIdentifier: "PARKER",
                secondaryIdentifier: ["PETER"],
                nationality: "USA",
                documentNumber: "5S280806",
                dateOfBirth: "010810",
                dateOfExpiry: "250718",
                gender: "MALE",
                optionalData1: "",
                optionalData2: nil
            ),
            facePhoto: Data(base64Encoded: "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"),
            signaturePhotos: [
                Data(base64Encoded: "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"
                    )!
            ],
            additionalPersonalDetails: EmrtdPassport.AdditionalPersonalDetails(
                fullNameOfHolder: "PETER BENJAMIN PARKER",
                otherNames: [],
                personalNumber: nil,
                fullDateOfBirth: "20010810",
                placeOfBirth: "NEW YORK USA",
                permanentAddress: nil,
                telephone: nil,
                profession: nil,
                title: nil,
                personalSummary: nil,
                proofOfCitizenshipImage: nil,
                otherValidTravelDocumentNumbers: nil,
                custodyInformation: nil
            ),
            additionalDocumentDetails: EmrtdPassport.AdditionalDocumentDetails(
                issuingAuthority: "UNITED STATES DEPARTMENT OF STATE",
                dateOfIssue: "20091116",
                namesOfOtherPersons: nil,
                endorsementsAndObservations: nil,
                taxOrExitRequirements: nil,
                imageOfFront: nil,
                imageOfRear: nil,
                dateAndTimeOfPersonalization: nil,
                personalizationSystemSerialNumber: nil
            ),
            passiveAuthentication: false,
            passiveAuthenticationDetails: EmrtdPassport.PassiveAuthenticationDetails(
                sodSignatureValid: true,
                documentCertificateValid: false,
                dataGroupsChecked: [1, 2, 7, 11, 12, 14, 15],
                dataGroupsWithValidHash: [1, 2, 7, 11, 12, 14, 15],
                allHashesValid: true,
                error: nil
            ),
            chipAuthenticationResult: .unavailable,
            activeAuthenticationResult: .unavailable,
            errors: [],
            filesBinary: nil
        )

        let jsonData = try! Data(contentsOf: testBundle.url(forResource: "peter_parker", withExtension: "json")!)
        let actual = try! decoder.decode(TextMessageFromServer.self, from: jsonData).emrtdPassport
        XCTAssert(expected == actual)
    }
}
