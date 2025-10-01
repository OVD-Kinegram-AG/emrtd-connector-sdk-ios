# ``EmrtdConnector``

Modern iOS SDK for KINEGRAM eMRTD verification using the v2 WebSocket protocol.

## Overview

The eMRTD Connector enables your iOS app to read and verify electronic passports and ID cards (eMRTDs) through the [Document Validation Server (DocVal)][docval]. This SDK implements a "fat client" architecture that performs most processing locally while maintaining server-side security validation.

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

## Why V2?

V2 solves the iOS 20-second NFC timeout issue by moving most APDU exchanges to the device. Instead of relaying every APDU through the server (causing latency to accumulate), V2 performs bulk reading locally and uses the server only for security-critical operations.

## Quick Start

```swift
import KinegramEmrtdConnector

// Initialize the connector
let connector = EmrtdConnector(
    serverURL: URL(string: "wss://server.example.com/ws2/validate")!,
    validationId: UUID().uuidString,
    clientId: "YOUR-CLIENT-ID"
)

// Simple one-call validation
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

[docval]: https://kta.pages.kurzdigital.com/kta-kinegram-document-validation-service/
