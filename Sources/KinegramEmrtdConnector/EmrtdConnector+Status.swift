//
//  EmrtdConnector.Status.swift
//  kinegram_emrtd_connector
//
//  Created by Tim Vogel on 04.01.22.
//

@available(iOS 13.0, *)
extension EmrtdConnector {
    ///
    /// Status cases that identify the current Step in a ``EmrtdConnector`` session.
    ///
    public enum Status: CustomStringConvertible {
        /// Reading File Atr/Info.
        case readAtrInfo
        /// Connecting to the WebSocket Server.
        case connectingToServer
        /// Performing Access Control.
        case accessControl
        /// Reading File SOD.
        case readSOD
        /// Reading Data Group 14.
        case readDG14
        /// Performing Chip Authentication.
        case chipAuthentication
        /// Reading Data Group 15.
        case readDG15
        /// Performing Active Authentication.
        case activeAuthentication
        /// Reading Data Group 1.
        case readDG1
        /// Reading Data Group 2.
        case readDG2
        /// Reading Data Group 7.
        case readDG7
        /// Reading Data Group 11.
        case readDG11
        /// Reading Data Group 12.
        case readDG12
        /// Performing Passive Authentication.
        case passiveAuthentication
        /// The DocVal Server finished the NFC Session.
        case done
        /// Fallback if the Status String from the DocVal Server has an unexpected Value
        case other(value: String)

        private static let values: [String: Status] = [
            "READ_ATR_INFO": .readAtrInfo,
            "CONNECTING_TO_SERVER": .connectingToServer,
            "ACCESS_CONTROL": .accessControl,
            "READ_SOD": .readSOD,
            "READ_DG14": .readDG14,
            "CHIP_AUTHENTICATION": .chipAuthentication,
            "READ_DG15": .readDG15,
            "ACTIVE_AUTHENTICATION": .activeAuthentication,
            "READ_DG1": .readDG1,
            "READ_DG2": .readDG2,
            "READ_DG7": .readDG7,
            "READ_DG11": .readDG11,
            "READ_DG12": .readDG12,
            "PASSIVE_AUTHENTICATION": .passiveAuthentication,
            "DONE": .done
        ]

        static func get(status: String?) -> Status? {
            if let status = status {
                return values[status] ?? .other(value: status)
            }
            return nil
        }

        /// Human Readable description of each case
        public var description: String {
            switch self {
            case .readAtrInfo:
                return "Reading File Atr/Info"
            case.connectingToServer:
                return "Connecting to Server"
            case .accessControl:
                return "Performing Access Control"
            case .readSOD:
                return "Reading File SOD"
            case .readDG14:
                return "Reading Data Group 14"
            case .chipAuthentication:
                return "Performing Chip Authentication"
            case .readDG15:
                return "Reading Data Group 15"
            case .activeAuthentication:
                return "Performing Active Authentication"
            case .readDG1:
               return "Reading Data Group 1"
            case .readDG2:
                return "Reading Data Group 2"
            case .readDG7:
                return "Reading Data Group 7"
            case .readDG11:
                return "Reading Data Group 11"
            case .readDG12:
                return "Reading Data Group 12"
            case .passiveAuthentication:
                return "Performing Passive Authentication"
            case .done:
                return "Done"
            case .other(value: let value):
                return value
            }
        }
    }
}
