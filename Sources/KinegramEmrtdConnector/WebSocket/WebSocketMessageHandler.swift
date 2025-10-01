import Foundation

/// Handles parsing and dispatching of WebSocket messages
actor WebSocketMessageHandler {
    private let decoder = JSONDecoder()

    init() {
        // Use default camelCase decoding
    }

    /// Parse a WebSocket message
    func parseMessage(_ message: URLSessionWebSocketTask.Message) throws -> ParsedMessage {
        switch message {
        case .string(let text):
            return try parseTextMessage(text)
        case .data(let data):
            return try parseBinaryMessage(data)
        @unknown default:
            throw MessageError.decodingFailed("Unknown message type")
        }
    }

    // MARK: - Text Message Parsing

    private func parseTextMessage(_ text: String) throws -> ParsedMessage {
        guard let data = text.data(using: .utf8) else {
            throw MessageError.decodingFailed("Invalid UTF-8 string")
        }

        // First decode just the type
        let typeContainer = try decoder.decode(MessageTypeContainer.self, from: data)

        // Then decode the full message based on type
        switch typeContainer.type {
        case .accept:
            let message = try decoder.decode(AcceptMessage.self, from: data)
            return .accept(message)

        case .caHandback:
            let message = try decoder.decode(CAHandbackMessage.self, from: data)
            return .caHandback(message)

        case .result:
            let message = try decoder.decode(ResultMessage.self, from: data)
            return .result(message)

        case .close:
            let message = try decoder.decode(CloseMessage.self, from: data)
            return .close(message)

        default:
            throw MessageError.decodingFailed("Unexpected message type from server: \(typeContainer.type)")
        }
    }

    // MARK: - Binary Message Parsing

    private func parseBinaryMessage(_ data: Data) throws -> ParsedMessage {
        guard data.count > 0 else {
            throw MessageError.invalidBinaryMessage
        }

        let messageType = data[0]

        switch messageType {
        case BinaryMessageType.file.rawValue:
            let fileMessage = try BinaryFileMessage.decode(from: data)
            return .binaryFile(fileMessage)

        case BinaryMessageType.apdu.rawValue:
            // APDU messages are used during CA handover
            let apduMessage = try BinaryAPDUMessage.decode(from: data)
            return .binaryAPDU(apduMessage)

        default:
            throw MessageError.wrongMessageType
        }
    }
}

// MARK: - Supporting Types

/// Container for decoding just the message type
private struct MessageTypeContainer: Decodable {
    let type: MessageType
}

/// Parsed message variants
enum ParsedMessage {
    case accept(AcceptMessage)
    case caHandback(CAHandbackMessage)
    case result(ResultMessage)
    case close(CloseMessage)
    case binaryFile(BinaryFileMessage)
    case binaryAPDU(BinaryAPDUMessage)

    var messageType: MessageType? {
        switch self {
        case .accept: return .accept
        case .caHandback: return .caHandback
        case .result: return .result
        case .close: return .close
        case .binaryFile, .binaryAPDU: return nil // Binary messages don't have MessageType
        }
    }
}

// MARK: - Message Encoding

extension WebSocketMessageHandler {
    /// Encode a message for sending
    func encodeMessage(_ message: any WebSocketMessage) throws -> String {
        let encoder = JSONEncoder()
        // Use default camelCase encoding
        let data = try encoder.encode(message)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw MessageError.decodingFailed("Failed to encode message as UTF-8")
        }

        return jsonString
    }

    /// Create binary file messages from data
    func createFileMessages(fileId: String, data: Data, chunkSize: Int = 32768) -> [BinaryFileMessage] {
        // In the actual v2 protocol, there's no chunking - send the whole file
        return [BinaryFileMessage(fileName: fileId, data: data)]
    }
}
