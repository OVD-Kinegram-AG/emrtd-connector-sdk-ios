# Handling Errors

Learn how to handle errors and edge cases in the eMRTD Connector V2.

## Error Types

The SDK provides comprehensive error handling through the `EmrtdConnectorError` enum and re-exported `EmrtdReaderError` from KinegramEmrtd.

### Connection Errors

```swift
do {
    let result = try await connector.validate(with: accessKey)
} catch EmrtdConnectorError.connectionFailed {
    // WebSocket connection failed
    print("Could not connect to server")
} catch EmrtdConnectorError.connectionTimeout {
    // Connection timed out (20s iOS limit)
    print("Connection timed out - try again")
} catch EmrtdConnectorError.connectionClosed(let reason) {
    // Connection closed unexpectedly
    print("Connection closed: \(reason)")
}
```

### NFC Errors

```swift
catch EmrtdConnectorError.nfcNotAvailable(let reason) {
    // NFC not available on device
    print("NFC not available: \(reason)")
} catch EmrtdConnectorError.incompleteRead(let missingFiles, let reason) {
    // Required files could not be read (e.g., NFC interruption)
    print("Missing files: \(missingFiles.joined(separator: ", "))")
    print("\(reason)")
} catch EmrtdReaderError.tagConnectionLost {
    // User moved passport away
    print("Connection lost - hold passport steady")
} catch EmrtdReaderError.accessControlFailed {
    // Wrong MRZ/CAN
    print("Access denied - check your access key")
}
```

### Protocol Errors

```swift
catch EmrtdConnectorError.protocolError(let message) {
    // Server protocol violation
    print("Protocol error: \(message)")
} catch EmrtdConnectorError.invalidServerResponse(let details) {
    // Invalid server response
    print("Invalid response: \(details)")
}
```

### Server Errors

The server may close the connection with specific error codes and reasons:

```swift
catch EmrtdConnectorError.serverError(let code, let message, let reason) {
    // The SDK automatically parses known close reasons
    if let reason = reason {
        print(reason.localizedDescription)
        
        // You can also check specific reasons
        switch reason {
        case .invalidClientId:
            // Handle invalid client ID (code 4401)
        case .accessControlFailed:
            // Wrong MRZ/CAN (code 4403)
        case .nfcChipCommunicationFailed:
            // Passport moved away (code 1001)
        default:
            break
        }
    } else {
        // Fallback to raw message
        print("Server error \(code): \(message ?? "")")
    }
}
```

#### Common Close Reasons

| Reason | Description | Code | Solution |
|--------|-------------|------|----------|
| `INVALID_CLIENT_ID` | Client ID not recognized | 4401 | Check your client ID configuration |
| `ACCESS_CONTROL_FAILED` | Wrong MRZ/CAN | 4403 | Verify document details |
| `NFC_CHIP_COMMUNICATION_FAILED` | Lost NFC connection | 1001 | Hold passport steady |
| `TIMEOUT_WHILE_WAITING_FOR_RESPONSE` | Device took too long | 1001 | Ensure stable connection |
| `INVALID_ACCESS_KEY_VALUES` | Invalid MRZ format | 1008 | Check date formats (YYMMDD) |
| `SERVER_ERROR` | Internal server error | 1011 | Contact support |
| `FILE_READ_ERROR` | Failed to read document file | 1011 | Try again |

## Complete Error Handling Example

```swift
class DocumentValidator {
    func validateDocument() async {
        let connector = EmrtdConnector(
            serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
            validationId: UUID().uuidString,
            clientId: "YOUR-CLIENT-ID"
        )
        
        do {
            let result = try await connector.validate(with: accessKey)
            handleSuccess(result)
            
        } catch EmrtdConnectorError.nfcNotAvailable(let reason) {
            showError("NFC is not available: \(reason)")
            
        } catch EmrtdConnectorError.connectionTimeout {
            showError("The operation timed out. Please try again and hold your passport steady.")
            
        } catch EmrtdConnectorError.incompleteRead(let missingFiles, _) {
            showError("Could not read all required data. Missing: \(missingFiles.joined(separator: ", ")). Please try again and hold passport steady.")
            
        } catch EmrtdReaderError.accessControlFailed {
            showError("Access denied. Please check your document details.")
            
        } catch EmrtdReaderError.tagConnectionLost {
            showError("Connection lost. Please hold your passport steady and try again.")
            
        } catch EmrtdConnectorError.connectionFailed {
            showError("Could not connect to server. Please check your internet connection.")
            
        } catch EmrtdConnectorError.serverError(let code, let message, let reason) {
            // Handle specific server errors with parsed reasons
            if let reason = reason {
                switch reason {
                case .invalidClientId:
                    showError("Invalid client ID. Please check your configuration.")
                case .accessControlFailed:
                    showError("Access denied. Please check your document details.")
                case .invalidAccessKeyValues:
                    showError("Invalid document details. Please check the format.")
                case .nfcChipCommunicationFailed:
                    showError("Lost connection to document. Please try again.")
                default:
                    showError(reason.localizedDescription)
                }
            } else {
                showError(message ?? "Server error \(code)")
            }
            
        } catch is CancellationError {
            // User cancelled - no need to show error
            print("Operation cancelled by user")
            
        } catch {
            showError("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
}
```

## Retry Strategy

For transient errors, implement retry logic in your application:

```swift
func validateWithRetry(maxAttempts: Int = 3) async throws -> ValidationResult {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await connector.validate(with: accessKey)
        } catch {
            lastError = error
            
            // Don't retry certain errors
            if error is CancellationError ||
               (error as? EmrtdReaderError)?.code == .accessControlFailed {
                throw error
            }
            
            // Wait before retry
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    throw lastError ?? EmrtdConnectorError.unknown
}
```

## Timeout Handling

iOS limits NFC sessions to 20 seconds. Handle timeouts gracefully:

```swift
connector.delegate = self

func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {
    // Show progress to user
    updateUI(with: status.alertMessage)
    
    // Warn if taking too long
    if status.step == .readingDG2 {
        showWarning("Please hold passport steady...")
    }
}
```

## Error Recovery

### Clean Up After Errors

The SDK automatically cleans up on errors, but you can ensure proper cleanup:

```swift
defer {
    Task {
        await connector.disconnect()
    }
}

do {
    let result = try await connector.validate(with: accessKey)
    // Process result
} catch {
    // Error is thrown after cleanup
    handleError(error)
}
```

### User-Friendly Error Messages

```swift
extension Error {
    var userFriendlyMessage: String {
        switch self {
        case EmrtdConnectorError.nfcNotAvailable:
            return "This device doesn't support NFC"
        case EmrtdConnectorError.connectionTimeout:
            return "Reading took too long. Please try again."
        case EmrtdConnectorError.incompleteRead:
            return "Could not read all required passport data. Please try again."
        case EmrtdConnectorError.serverError(_, _, let reason?):
            return reason.localizedDescription
        case EmrtdReaderError.accessControlFailed:
            return "Could not access passport. Please check the details you entered."
        case EmrtdReaderError.tagConnectionLost:
            return "Lost connection. Please hold your passport still."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
```

## Debugging

Debug logging is automatically enabled in DEBUG builds. The logs will show:
- WebSocket messages
- State transitions  
- NFC operations
- Error details

## Common Issues and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `accessControlFailed` | Wrong MRZ/CAN | Double-check document details |
| `connectionTimeout` | Slow connection or movement | Use stable WiFi, hold passport steady |
| `tagConnectionLost` | Passport moved | Keep passport still during reading |
| `incompleteRead` | Required files missing (e.g., DG2) | Hold passport steady throughout entire process |
| `nfcNotAvailable` | NFC disabled or unavailable | Check device settings |
| `protocolError` | Server compatibility | Check server version/configuration |
