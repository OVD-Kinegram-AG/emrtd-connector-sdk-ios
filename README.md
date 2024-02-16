# Kinegram eMRTD Connector SDK iOS

Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD through a
WebSocket connection.

## Example App

The Xcode Project `Sources/ExampleApp.xcodeproj` contains an Example App to demonstrate usage and functionality.

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

## Usage and API description

[DocC documentation][documentation]

## Changelog

[Changelog](CHANGELOG.md)

[add-packages]: https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app
[using-cocoapods]: https://guides.cocoapods.org/using/using-cocoapods.html
[documentation]: https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios/documentation/kinegramemrtdconnector
