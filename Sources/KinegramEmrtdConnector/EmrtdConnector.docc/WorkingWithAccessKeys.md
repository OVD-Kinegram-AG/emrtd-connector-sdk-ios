# Working with Access Keys

Learn how to use MRZ and CAN access keys to read eMRTD documents.

## Overview

To access an eMRTD chip, you need to provide authentication credentials. The SDK supports two types of access keys:

- **MRZ Key**: Using document number, date of birth, and date of expiry from the Machine Readable Zone
- **CAN Key**: Using the Card Access Number printed on the document

## MRZ Key

The MRZ (Machine Readable Zone) contains the document information printed at the bottom of passports and ID cards.

### Creating an MRZ Key

```swift
let mrzKey = MRZKey(
    documentNumber: "P1234567",
    birthDateyyMMdd: "900515",    // Format: yyMMdd
    expiryDateyyMMdd: "251231"    // Format: yyMMdd
)
```

### Date Format

Dates must be provided in `yyMMdd` format:
- `"900515"` = May 15, 1990
- `"251231"` = December 31, 2025
- `"010101"` = January 1, 2001

### Document Number

The document number should be provided exactly as it appears in the MRZ:
- Remove any spaces
- Include check digits if present
- Maximum 9 characters

### Example from MRZ

Given this MRZ:
```
P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<
L898902C36UTO7408122F1204159ZE184226B<<<<<10
```

Extract:
- Document Number: `L898902C3`
- Birth Date: `740812` (August 12, 1974)
- Expiry Date: `120415` (April 15, 2012)

## CAN Key

The CAN (Card Access Number) is a 6-digit number printed on the document, typically on the front of ID cards.

### Creating a CAN Key

```swift
let canKey = CANKey(can: "123456")
```

### CAN Format

- Exactly 6 digits
- No spaces or separators
- Usually printed near the document number

## Choosing Between MRZ and CAN

### Use MRZ when:
- Working with passports (always have MRZ)
- You have OCR capabilities to read the MRZ
- Users are familiar with their document details

### Use CAN when:
- Working with ID cards that have CAN
- You want a simpler user experience (just 6 digits)
- The CAN is clearly visible on the document

## Access Control Protocols

The SDK automatically selects the appropriate access control protocol:

- **BAC** (Basic Access Control): Older passports
- **PACE** (Password Authenticated Connection Establishment): Newer passports and ID cards

Both MRZ and CAN keys can use either protocol - the SDK handles this automatically.

## Usage Example

```swift
// Using MRZ
let mrzKey = MRZKey(
    documentNumber: "P1234567",
    birthDateyyMMdd: "900101",
    expiryDateyyMMdd: "250101"
)

let result = try await connector.validate(with: mrzKey)

// Using CAN
let canKey = CANKey(can: "123456")
let result = try await connector.validate(with: canKey)
```

## Error Handling

Common access key errors:

```swift
do {
    let result = try await connector.validate(with: accessKey)
} catch EmrtdReaderError.accessControlFailed {
    // Wrong access key - check MRZ/CAN values
} catch EmrtdReaderError.invalidAccessKey {
    // Malformed access key
} catch {
    // Other errors
}
```

## Security Considerations

- Never log or store access keys in plain text
- Access keys are sensitive personal data
- Clear from memory after use
- Use secure input methods in your UI