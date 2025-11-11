# Kinegram eMRTD Connector SDK iOS - Changelog

## 2.1.2

* Fix: Stabilize fire-and-forget mode (`receiveResult=false`)
* Example: Hide result output when `receiveResult=false`

## 2.1.1

* Fix: Remove NFC race‑guard and double‑cleanup; update KinegramEmrtd framework for stable async flow

## 2.1.0

* New: Automatic PACE selection based on document info
  * New overloads: `validate(with:documentType:issuingCountry:)` and `startValidation(..., documentType:issuingCountry:)`
  * Enables PACE polling automatically for known PACE-enabled ID cards (currently FRA, OMN), keeps it off for passports
* New: `DocumentType` enum and MRZ helper `DocumentType.fromMRZDocumentCode(_:)`
* Fix: Improve robustness of WebSocket connect/teardown

## 2.0.15

* **New Feature**: Add `usePACEPolling` parameter to support more documents
  * Required for reading French ID cards (FRA ID), Omani ID cards (OMN ID), etc.
  * Please be aware, that this requires changes to your app's entitlements (add `PACE` to `com.apple.developer.nfc.readersession.formats`) as described in the README

## 2.0.14

* Added support for CocoaPods again (in addition to SPM)

_Notice: The recommended way is to integrate the SDK via SPM, as cocoapods is only in maintenance mode since 2024-09 (see [official announcement](https://blog.cocoapods.org/CocoaPods-Support-Plans/))_

## 2.0.13

### Major Version Release - V2

This is a **major rewrite** of the eMRTD Connector SDK with significant architectural changes and breaking changes from V1.

**✨ Key Improvements:**
- Solves the iOS 20-second NFC timeout issue by moving APDU exchanges to the device
- Simple one-call validation API with `validate(with:)`
- Modern Swift concurrency with async/await
- Improved error handling and progress reporting

**⚠️ Breaking Changes:**
- **New WebSocket protocol** - Uses v2 protocol
- **Complete API redesign** - Async/await based, simplified interface
- **Minimum iOS version increased** from iOS 13.0 to iOS 15.0
- **Swift Package Manager only** - CocoaPods support removed
- **Binary dependency required** - Now includes `KinegramEmrtd.xcframework`

**📚 Migration:**
See [MIGRATION_V1_TO_V2.md](MIGRATION_V1_TO_V2.md) for detailed migration instructions from V1.

## 1.2.1

* Add a flag `enableDiagnostics` to interface functions for enabling diagnostics in the DocVal server.

## 1.2.0

* Add support for setting custom HTTP headers for the WebSocket connection. See `connect` method in `EmrtdConnector` class.

## 1.1.3

* Seperate github build jobs (no functional change to framework)

## 1.1.2

* Optimized github build action (no functional change)

## 1.1.1

* Added also validationID to ObjC interface

## 1.1.0

* Add a simplified and ObjectiveC compatible version, build as static framework. See folder `ObjCFramework` for more info.

## 1.0.0

* Improve documentation
* Rename library module from `KTAKinegramEmrtdConnector` to `KinegramEmrtdConnector`!
Update your import statements accordingly.

## 0.0.9

* Add instruction to set "Team" in signings config to Readme

## 0.0.8

* Also parse the optional field "files_binary" in the EmrtdPassport Result JSON

## 0.0.4

* Show Details if Passive Authentication not successful
* Enforce Document Number to be Upper Case
* Minor Improvements to the Documentation

## 0.0.3

* Minor Improvements to the Documentation

## 0.0.2

* Improvements to the API of `EmrtdConnector`
* Make Example App use revised EmrtdConnector API
* Additions to the Documentation

## 0.0.1

* Everything begins
