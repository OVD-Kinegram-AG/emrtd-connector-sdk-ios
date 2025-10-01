# Migration Guide: V1 to V2

This guide helps you migrate from eMRTD Connector SDK V1 to V2.

## Key Changes

### 1. WebSocket Endpoint
```swift
// V1: /ws1/validate
"wss://docval.kurzdigital.com/ws1/validate"

// V2: /ws2/validate
"wss://docval.kurzdigital.com/ws2/validate"
```

### 2. API Changes

#### V1 - Manual NFC Session Management
```swift
class ViewController: NFCTagReaderDelegate, EmrtdConnectorDelegate {
    
    func startValidation() {
        // Manual NFC session
        let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session.begin()
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first,
              case .iso7816(let passportTag) = tag else { return }
        
        session.connect(to: tag) { error in
            self.connector.connect(
                to: passportTag,
                vId: UUID().uuidString,
                documentNumber: "P1234567",
                dateOfBirth: "900101",
                dateOfExpiry: "250101"
            )
        }
    }
    
    func emrtdConnector(_ connector: EmrtdConnector, didReceiveEmrtdPassport passport: EmrtdPassport?) {
        // Handle result
    }
}
```

#### V2 - Simplified async/await API
```swift
class ViewController {
    
    func startValidation() async {
        let connector = EmrtdConnector(
            serverURL: URL(string: "wss://server.com/ws2/validate")!,
            validationId: UUID().uuidString,
            clientId: "YOUR-CLIENT-ID"
        )
        
        let mrzKey = MRZKey(
            documentNumber: "P1234567",
            birthDateyyMMdd: "900101",
            expiryDateyyMMdd: "250101"
        )
        
        do {
            // Automatic NFC session management
            let result = try await connector.validate(with: mrzKey)
            
            if result.isValid {
                print("Valid: \(result.mrzInfo?.primaryIdentifier ?? "")")
            }
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## Main Differences

| Feature | V1 | V2 |
|---------|-----|-----|
| **NFC Session** | Manual `NFCTagReaderSession` | Automatic |
| **Connection** | `connect(to:vId:...)` | `validate(with:)` |
| **API Style** | Delegate callbacks | async/await |
| **Access Keys** | Separate parameters | `MRZKey` or `CANKey` objects |
| **Result Type** | `EmrtdPassport` | `ValidationResult` |
| **Error Handling** | Delegate method | Swift native errors |

## Quick Migration Steps

1. **Change endpoint** from `/validate` to `/ws2/validate`
2. **Remove** all `NFCTagReaderSession` code
3. **Replace** delegate methods with async/await
4. **Use** type-safe `MRZKey` or `CANKey` objects

## Error Handling

```swift
// V2 provides detailed error types
do {
    let result = try await connector.validate(with: accessKey)
} catch EmrtdConnectorError.nfcNotAvailable(let reason) {
    // NFC not available
} catch EmrtdConnectorError.connectionTimeout {
    // Timeout
} catch EmrtdReaderError.accessControlFailed {
    // Wrong MRZ/CAN
}
```

## Optional Features

### Progress Updates (V2)
```swift
// Set delegate for progress
connector.delegate = self

func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {
    print(status.alertMessage)  // "Reading Document Data\n▮▮▮▮▯▯▯"
}
```

### Localization
```swift
connector.nfcStatusLocalization = { status in
    // Return localized message
    return NSLocalizedString("nfc.\(status.step)", comment: "")
}
```

## Need Help?

For support, contact KINEGRAM with your specific migration questions.
