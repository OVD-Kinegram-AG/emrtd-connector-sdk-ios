# Getting Started

Quick integration guide for the eMRTD Connector SDK.

## Installation

Add the package via Swift Package Manager using the repository URL provided by KINEGRAM.

**Requirements:** iOS 15.0+, Swift 5.5+, Physical device with NFC

## Setup Your App: Requirements Setup

### 1. Enable NFC Capability

This needed entitlement is added automatically by Xcode when enabling the
**Near Field Communication Tag Reading** capability in the target
**Signing & Capabilities**.

After enabling the capability the `*.entitlements` file needs to contain
the `TAG` _(Application specific tag, including ISO 7816 Tags)_ and `PACE` _(Needed for PACE polling support (some ID cards))_ format:

```xml
...
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>PACE</string>
        <string>TAG</string>
    </array>
</dict>
...
```


### 2. Info.plist (AID & NFCReaderUsageDescription)

The app needs to define the list of `AIDs` it can connect to, in the `Info.plist` file.

The `AID` is a way of uniquely identifying an application on a ISO 7816 tag.
eMRTDS use the AIDs `A0000002471001` and `A0000002472001`.
Your *Info.plist* entry should look like this:

```xml
    <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
    <array>
        <string>A0000002471001</string>
        <string>A0000002472001</string>
    </array>
```

- Additionally set the `NFCReaderUsageDescription` key:

```xml
    <key>NFCReaderUsageDescription</key>
    <string>This app uses NFC to verify passports</string>
```


## Basic Implementation

### Simple One-Call Validation

```swift
import KinegramEmrtdConnector

class DocumentValidator {
    func validateDocument() async {
        // Create connector
        let connector = EmrtdConnector(
            serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
            validationId: UUID().uuidString,
            clientId: "YOUR-CLIENT-ID"
        )
        
        // Create access key (MRZ or CAN)
        let mrzKey = MRZKey(
            documentNumber: "P1234567",
            birthDateyyMMdd: "900101",
            expiryDateyyMMdd: "250101"
        )
        
        do {
            // Validate - connection and disconnection are automatic!
            let result = try await connector.validate(with: mrzKey)
            
            if result.isValid {
                print("Valid document")
                print("Name: \(result.mrzInfo?.primaryIdentifier ?? "")")
            } else {
                print("Invalid document")
            }
        } catch {
            print("Validation failed: \(error)")
        }
    }
}
```

### With Progress Updates

```swift
import KinegramEmrtdConnector

class DocumentValidator: EmrtdConnectorDelegate {
    private var connector: EmrtdConnector?
    
    func validateDocument() async {
        connector = EmrtdConnector(
            serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
            validationId: UUID().uuidString,
            clientId: "YOUR-CLIENT-ID"
        )
        
        // Set delegate for progress updates
        connector?.delegate = self
        
        let canKey = CANKey(can: "123456")
        
        do {
            let result = try await connector?.validate(with: canKey)
            // Handle result...
        } catch {
            // Handle error...
        }
    }
    
    // MARK: - EmrtdConnectorDelegate
    
    func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {
        print("NFC Status: \(status.alertMessage)")
        // Update UI with progress...
    }
    
    func connector(_ connector: EmrtdConnector, didFailWithError error: Error) async {
        print("Error: \(error)")
    }
}
```

### Reading PACE-enabled Documents

Some identity documents require PACE (Password Authenticated Connection Establishment) polling to be detected. This includes French ID cards (FRA ID) and Omani ID cards (OMN ID).

```swift
import KinegramEmrtdConnector

class DocumentValidator {
    func validatePACEDocument() async {
        let connector = EmrtdConnector(
            serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
            validationId: UUID().uuidString,
            clientId: "YOUR-CLIENT-ID"
        )

        let canKey = CANKey(can: "123456")

        do {
            // Enable PACE polling for PACE-enabled documents (requires iOS 16+)
            let result = try await connector.validate(with: canKey, usePACEPolling: true)

            if result.isValid {
                print("Valid document")
            }
        } catch EmrtdReaderError.PACEPollingNotAvailable {
            print("PACE polling requires iOS 16 or later")
        } catch {
            print("Validation failed: \(error)")
        }
    }
}
```

> Important: PACE polling is only available on iOS 16 and later. It cannot detect standard passports - use it only when you know the document requires it.

## Custom HTTP Headers (Optional)

Most users don't need custom headers. This feature is only for specific use cases where your result server requires additional authentication or metadata. The headers will be forwarded by DocVal to your result server.

```swift
// Only if your server requires it:
let headers = [
    "Authorization": "Bearer your-token",
    "X-Custom-Header": "value"
]

let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID",
    httpHeaders: headers  // Optional - most users can omit this
)
```

## Custom NFC Status Messages (Optional)

Customize or localize NFC dialog messages, including error messages:

```swift
connector.nfcStatusLocalization = { status in
    switch status.step {
    case .error:
        return ""  // Hide error text, show only icon
    case .waitingForPassport:
        return "Place document on phone"
    case .readingDG2:
        return "Reading photo..."
    default:
        return status.alertMessage  // Use default
    }
}
```

## Diagnostics and Monitoring

The SDK provides built-in diagnostics and monitoring capabilities for debugging and telemetry purposes.

### Enable Diagnostics Mode

To enable diagnostic data collection and transmission to the server:

```swift
let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID",
    enableDiagnostics: true  // Enable diagnostic data transmission
)
```

When enabled, diagnostic messages are automatically sent to the DocVal server for analysis.

### Monitoring Delegate

For local monitoring and debugging, implement the `EmrtdConnectorMonitoringDelegate`:

```swift
class MyMonitoringHandler: EmrtdConnectorMonitoringDelegate {
    func connector(_ connector: EmrtdConnector, 
                   didReceiveMonitoringMessage message: String) async {
        // Log monitoring events for debugging
        print("[MONITORING] \(message)")
        
        // You can also:
        // - Save to a log file
        // - Send to your analytics service
        // - Display in a debug console
    }
}

// Set the monitoring delegate
connector.monitoringDelegate = myMonitoringHandler
```

### What Monitoring Data Includes

The monitoring messages include:
- NFC communication details
- Error details and stack traces

### Important Notes

- **Performance**: Monitoring has minimal performance impact but generates additional network traffic when `enableDiagnostics` is true.
- **Server Support**: The `enableDiagnostics` flag requires server-side support for receiving diagnostic messages (from DocVal version 1.9.0+)

## Next Steps

- See <doc:WorkingWithAccessKeys> for MRZ and CAN details
- See <doc:HandlingErrors> for comprehensive error handling
