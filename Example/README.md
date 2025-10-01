# eMRTD Connector Example App

This example app demonstrates how to integrate the EmrtdConnector SDK into your iOS application with support for both CAN (Card Access Number) and MRZ (Machine Readable Zone) validation.

## What This Example Shows

- **Simplified API**: One-call validation with automatic connection/disconnection
- **Support for both CAN and MRZ** validation methods
- **NFC Progress Updates**: Visual progress bars in the NFC dialog
- **Comprehensive debug logging** to understand the flow

## Architecture

The example follows MVVM pattern:
- **ConnectorExampleApp.swift**: App entry point
- **ContentView.swift**: SwiftUI interface with tabs for CAN/MRZ input
- **ConnectorViewModel.swift**: Business logic, state management, and delegate handling

## Key Integration Steps

1. **Import the SDK**
   ```swift
   import KinegramEmrtdConnector
   ```

2. **Create the Connector**
   ```swift
   let connector = EmrtdConnector(
       serverURL: url,
       validationId: UUID().uuidString,
       clientId: "YOUR_CLIENT_ID"
   )
   
   // Optional: With custom headers (only if your result server needs them)
   let headers = ["Authorization": "Bearer token"]
   let connector = EmrtdConnector(
       serverURL: url,
       validationId: UUID().uuidString,
       clientId: "YOUR_CLIENT_ID",
       httpHeaders: headers  // Headers are forwarded by DocVal to your result server
   )
   ```

3. **Set the Delegate** (optional for progress updates)
   ```swift
   connector.delegate = self
   ```

4. **Validate with the new simplified API**
   ```swift
   // CAN validation
   let canKey = CANKey(can: "123456")  // 6-digit CAN
   let result = try await connector.validate(with: canKey)
   
   // OR MRZ validation
   let mrzKey = MRZKey(
       documentNumber: "P1234567",
       birthDateyyMMdd: "900101",
       expiryDateyyMMdd: "251231"
   )
   let result = try await connector.validate(with: mrzKey)
   ```
   
   That's it! Connection and disconnection are handled automatically.

5. **Handle the Result**
   ```swift
   if result.isValid {
       print("Valid document")
       print("Name: \(result.mrzInfo?.primaryIdentifier ?? "")")
       print("Document: \(result.mrzInfo?.documentNumber ?? "")")
   } else {
       print("Invalid document: \(result.status)")
   }
   ```

## Debug Output

The example includes comprehensive debug prints to help understand the flow:
- Connection process
- Validation steps
- Delegate callbacks
- Error handling

Look for prints with these prefixes in the console:
- 🔌 Connection events
- 📋 Validation setup
- 🔐 CAN/MRZ validation
- 📡 Delegate callbacks
- 📱 NFC Status updates (progress bars)
- ✅ Success states
- ❌ Error states
- 🚀 API calls

## Setup Requirements

### 1. Capabilities
Enable the following capability in your project:
- **Near Field Communication Tag Reading**

### 2. Info.plist
Add the NFC usage description:
```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to read eMRTD documents</string>
```

### 3. Entitlements
Add to your .entitlements file:
```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
    <string>TAG</string>
</array>
```

## Features Demonstrated

### 📱 NFC Progress Updates
The app shows visual progress bars in the NFC dialog:
```
Hold passport near phone
▯▯▯▯▯▯▯

Performing Access Control
▮▯▯▯▯▯▯

Reading Security Data
▮▮▯▯▯▯▯

Reading Document Data
▮▮▮▮▯▯▯

Completing
▮▮▮▮▮▮▮
```

### 🔄 Automatic Connection Management
- No need to manually connect/disconnect
- The `validate()` method handles everything
- Proper cleanup on errors
- Reconnection handled automatically

### 📡 Delegate Callbacks
All delegate methods are optional:
- `connectorDidConnect` - Connection established
- `connectorWillReadChip` - NFC reading starting
- `connector(_:didUpdateNFCStatus:)` - Progress updates with visual bars
- `connectorDidCompleteValidation` - Success with result
- `connector(_:didFailWithError:)` - Error handling

### 💾 User Experience Features
- Tab interface for CAN/MRZ selection
- Input validation (6 digits for CAN, proper format for MRZ)
- Saves last used values using `@AppStorage`
- Visual feedback for validation status
- Clear error messages

## Running the Example

1. Open `ConnectorExample.xcodeproj`
2. Select your development team for code signing
3. Run on a physical device (NFC not available in simulator)
4. Enter a CAN or MRZ and tap "Validate Document"
5. Hold your passport to the phone when prompted

## Notes

- The server URL (`kinegramdocval-slim.integ.kurz.digital`) is for demo purposes
- Client ID `DEMO-01` is for testing
- In production, use your own server endpoint and credentials
- The validation ID is automatically generated as a UUID
- All SDK methods are async and use Swift's modern concurrency