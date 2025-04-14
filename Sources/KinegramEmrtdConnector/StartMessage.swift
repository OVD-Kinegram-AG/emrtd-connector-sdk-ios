//
//  StartMessage.swift
//  kds_emrtd_connector
//
//  Created by Tim Vogel on 07.01.22.
//

import Foundation

/// A structure representing a start message used for initializing a connection.
///
/// The `StartMessage` struct is responsible for encoding the necessary data
/// to initiate a connection.
struct StartMessage: Encodable {
    let clientId: String
    let validationId: String
    let accessKey: [String: String]
    let nfcAdapterSupportsExtendedLength: Bool = true
    var maxCommandBytes: Int?
    var maxResponseBytes: Int?
    let platform = "ios"
    var enableDiagnostics: Bool? = nil

    func asJsonString() -> String {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case validationId = "validation_id"
        case accessKey = "access_key"
        case nfcAdapterSupportsExtendedLength = "nfc_adapter_supports_extended_length"
        case maxCommandBytes = "max_command_bytes"
        case maxResponseBytes = "max_response_bytes"
        case platform
        case enableDiagnostics = "enable_diagnostics"
    }
}
