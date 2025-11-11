# KINEGRAM eMRTD Connector iOS SDK

iOS SDK for KINEGRAM eMRTD verification using the v2 WebSocket protocol.

```
    ┌───────────────┐     Results     ┌─────────────────┐
    │ DocVal Server │────────────────▶│   Your Server   │
    └───────────────┘                 └─────────────────┘
            ▲
            │ WebSocket v2
            ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        ┃
┃  eMRTD Connector       ┃
┃                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━┛
            ▲
            │ NFC
            ▼
    ┌──────────────┐
    │              │
    │   PASSPORT   │
    │              │
    │   ID CARD    │
    │              │
    │              │
    │   (eMRTD)    │
    │              │
    └──────────────┘
```

The *eMRTD Connector* enables the [Document Validation Server (DocVal)][docval] to read and verify eMRTD documents through a secure WebSocket connection.

## Why V2?

V2 solves the iOS 20-second NFC timeout issue by moving most APDU exchanges to the device. Instead of relaying every APDU through the server (causing latency to accumulate), V2 performs bulk reading locally and uses the server only for security-critical operations.

**Upgrading from V1?** See the [Migration Guide](MIGRATION_V1_TO_V2.md) for detailed instructions.

## Features

- ✅ **Simple one-call validation API** - just `validate(with:)`
- ✅ **iOS 15+ with async/await** - modern Swift concurrency
- ✅ **APDU relay for Chip Authentication** - secure server-side verification

## Requirements

- iOS 15.0+
- Swift 5.5+
- Physical device with NFC capability
- KinegramEmrtd.xcframework (included)


## Installation

### Swift Package Manager (Recommended)

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/OVD-Kinegram-AG/emrtd-connector-sdk-ios", from: "2.1.0")
]
```

The package includes the KinegramEmrtd.xcframework binary dependency automatically.

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'KinegramEmrtdConnector', '~> 2.1.1'
```

Then run `pod install`.

> **Note:** CocoaPods support is provided for compatibility with existing projects. However, we recommend using Swift Package Manager as CocoaPods is only in maintenance mode since September 2024 ([official announcement](https://blog.cocoapods.org/CocoaPods-Support-Plans/)).

## Quick Start

```swift
import KinegramEmrtdConnector

// Initialize connector
let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID"
)

// Validate with MRZ
let mrzKey = MRZKey(
    documentNumber: "P1234567",
    birthDateyyMMdd: "900101", 
    expiryDateyyMMdd: "250101"
)

let result = try await connector.validate(with: mrzKey)

if result.isValid {
    print("Document holder: \(result.mrzInfo?.primaryIdentifier ?? "")")
}
```

That's it! The SDK handles connection, validation, and disconnection automatically.

### Advanced Usage (Manual Connection)

If you need more control, you can still use the explicit connection approach:

```swift
// Connect first
try await connector.connect()

// Then validate
let result = try await connector.startValidation(accessKey: mrzKey)

// Disconnect when done
await connector.disconnect()
```

### Using with CAN

For passports that require CAN (Card Access Number):

```swift
let canKey = CANKey(can: "123456") // 6-digit CAN
let result = try await connector.validate(with: canKey)
```

### Reading PACE-enabled Documents

Some identity documents require PACE (Password Authenticated Connection Establishment) polling to be detected. This includes French ID cards (FRA ID) and Omani ID cards (OMN ID).

```swift
// Enable PACE polling for PACE-enabled documents (requires iOS 16+)
let canKey = CANKey(can: "123456")
let result = try await connector.validate(with: canKey, usePACEPolling: true)
```

**Important:**
- PACE polling is only available on iOS 16 and later
- **PACE polling cannot detect standard passports** - use it only when you know the document requires it
- A `PACEPollingNotAvailable` error will be thrown if you try to use PACE polling on iOS 15 or earlier

### Automatic PACE Selection (by document info)

If you don’t want to decide `usePACEPolling` yourself, you can provide the document type and issuing country and let the SDK decide. This currently enables PACE polling for known ID cards that require it (e.g., FRA ID, OMN ID) and keeps it disabled for standard passports.

```swift
// Auto-select PACE polling based on document info
// .idCard with country FRA enables PACE polling automatically
let canKey = CANKey(can: "123456")
// Option A: Specify document type explicitly
let result = try await connector.validate(
    with: canKey,
    documentType: .idCard,
    issuingCountry: "FRA" // ISO 3166-1 alpha-3
)

// Option B: Derive document type from MRZ document code prefix (e.g., "ID", "I<", "P<", "PM")
let docType = DocumentType.fromMRZDocumentCode("ID")
let result2 = try await connector.validate(
    with: canKey,
    documentType: docType,
    issuingCountry: "FRA"
)
```

Notes:
- You still need the PACE entitlement in your app when PACE might be used (see Requirements Setup).
- For unknown countries or for passports, the SDK defaults to no PACE polling (you can still use the manual flag if needed).

### Custom HTTP Headers (Optional)

If your server requires custom headers (e.g., for authentication), you can optionally provide them. These headers will be forwarded by DocVal to your result server:

```swift
let headers = [
    "Authorization": "Bearer your-token",
    "X-Custom-Header": "value"
]

let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID",
    httpHeaders: headers  // Optional parameter
)
```

Note: This is only for specific use cases where your result server requires additional authentication or metadata.

### Fire-and-Forget Mode (Optional)

If you don't need to receive the validation result back from the server, you can use the `receiveResult` parameter:

```swift
let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID",
    receiveResult: false
)

// The validate call will complete after sending data to server
try await connector.validate(with: mrzKey)
```

When `receiveResult` is false, the server won't send back the validation result, reducing latency and bandwidth usage.


## Documentation

Full API documentation is available at: [https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios/documentation/kinegramemrtdconnector](https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios/documentation/kinegramemrtdconnector)

## Example App

Check out the [Example](https://github.com/OVD-Kinegram-AG/emrtd-connector-sdk-ios/tree/main/Example) directory for a complete SwiftUI app demonstrating:
- MRZ and CAN validation
- Progress updates
- Error handling

## Error Handling

```swift
do {
    let result = try await connector.validate(with: mrzKey)
} catch EmrtdConnectorError.nfcNotAvailable(let reason) {
    print("NFC not available: \(reason)")
} catch EmrtdConnectorError.connectionTimeout {
    print("Timeout - hold passport steady")
} catch EmrtdConnectorError.incompleteRead(let missingFiles, let reason) {
    print("Missing files: \(missingFiles.joined(separator: ", "))")
    print("Reason: \(reason)")
} catch EmrtdReaderError.accessControlFailed {
    print("Wrong MRZ/CAN")
} catch {
    print("Error: \(error)")
}
```

## Progress Updates

```swift
// Set delegate for progress updates
connector.delegate = self

// Implement delegate method
func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {
    print(status.alertMessage)
    // Shows: "Reading Document Data\n▮▮▮▮▯▯▯"
}
```

## Server Post Confirmation

The SDK provides a delegate callback to confirm when the server has successfully posted results (Close Code 1000):

```swift
// This is called when server successfully posts to result server
func connectorDidSuccessfullyPostToServer(_ connector: EmrtdConnector) async {
    print("Server successfully posted results")
    // You can now proceed knowing the server processed the data
}
```

## Localization

The SDK provides English status messages by default. To localize the NFC dialog messages for your users:

```swift
// Configure localization before validation
connector.nfcStatusLocalization = { status in
    // Return your localized message based on the status
    switch status.step {
    case .waitingForPassport:
        return NSLocalizedString("nfc.waitingForPassport", comment: "")
    case .readingDG1:
        return NSLocalizedString("nfc.readingDocumentData", comment: "")
    // ... handle other cases
    default:
        return status.alertMessage // Fall back to English
    }
}

// The NFC dialog will now show your localized messages
let result = try await connector.validate(with: accessKey)
```

## Requirements Setup

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


## Debug Logging

Debug logging is automatically enabled in DEBUG builds. Log messages will appear in the console during development.


[docval]: https://kta.pages.kurzdigital.com/kta-kinegram-document-validation-service/
