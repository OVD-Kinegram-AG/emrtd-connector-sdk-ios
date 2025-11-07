# Kinegram eMRTD Connector SDK iOS

The Kinegram eMRTD Connector enables your iOS app to read and verify electronic passports / id cards ([eMRTDs][emrtd]).

```
    ┌───────────────┐     Results     ┌─────────────────┐
    │ DocVal Server │────────────────▶│   Your Server   │
    └───────────────┘                 └─────────────────┘
            ▲
            │ WebSocket
            ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        ┃
┃    eMRTD Connector     ┃
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

The *Kinegram eMRTD Connector* enables the [Document Validation Server (DocVal)][docval] to communicate with the eMRTD through a secure WebSocket connection.

## Example App

The Xcode Project `Sources/ExampleApp.xcodeproj` contains an Example App to demonstrate usage and functionality.

PACE-enabled IDs (e.g., French ID – FRA) on iOS:
- Add `PACE` (and `TAG`) to `com.apple.developer.nfc.readersession.formats` entitlements
- Include AIDs `A0000002471001` and `A0000002472001` in Info.plist
- Start `NFCTagReaderSession` with `.pace` (iOS 16+) for PACE IDs; use `.iso14443` for non‑PACE docs
- `.pace` is exclusive and cannot be combined with other polling options

### Requirements

* **Xcode 15** or later
* Device Running iOS 13.0 or later (because of the iOS NFC APIs)

### Runnning

Set your Team in the `Signing & Capabilities` settings for all Targets in this project.

Select the scheme `ExampleApp` and click **Run**.

## Include the Kinegram eMRTD Connector in your app

The Swift Package can be included in apps with Deployment Target 11.0 or later.

### Swift Package Manager

[Adding package dependencies to your app][add-packages]

1. Select _File_ -> _Add Package Dependencies..._ and paste this repository's URL `https://github.com/OVD-Kinegram-AG/emrtd-connector-sdk-ios.git` into the search field.
2. Select **your Project** and click `Add Package`.
3. Add **your App's Target** for the product `KinegramEmrtdConnector` and click `Add Package`.

### CocoaPods

[Using CocoaPods][using-cocoapods]

Add the pod `KinegramEmrtdConnector` to your Podfile.

```
target 'MyApp' do
  pod 'KinegramEmrtdConnector', '~> 1.0.0'
end
```

Run `$ pod install` in your project directory.

### ObjC compatible version of *KinegramEmrtdConnector*

There is an Objective-C compatible version of this connector in the `ObjCFramework` folder, which was built as a static framework. This `KinegramEmrtdConnectorObjC.xcframework` can be used by ObjC-only projects and also by common cross-platform projects (.net MAUI, Flutter, ReactNative) that cannot yet handle the Swift interface. More info in [ObjCFramework/README.md](ObjCFramework/README.md)

## Usage and API description

[DocC documentation][documentation]

## Changelog

[Changelog](CHANGELOG.md)

## Privacy Notice

ℹ️ [Privacy Notice][privacy-notice]

[emrtd]: https://kta.pages.kurzdigital.com/kta-kinegram-document-validation-service/Security%20Mechanisms
[docval]: https://kta.pages.kurzdigital.com/kta-kinegram-document-validation-service/
[add-packages]: https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app
[using-cocoapods]: https://guides.cocoapods.org/using/using-cocoapods.html
[documentation]: https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios/documentation/kinegramemrtdconnector
[privacy-notice]: https://kinegram.digital/privacy-notice/
