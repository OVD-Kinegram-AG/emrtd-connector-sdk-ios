# Kinegram eMRTD Connector – Objective-C Framework

The Objective-C compatible version of the Kinegram eMRTD Connector SDK provides a static framework that can be used in Objective-C projects as well as cross-platform frameworks like .NET MAUI, Flutter, and React Native.

## Features

- **Objective-C Compatibility**: Fully compatible with Objective-C projects.
- **Static Framework**: Distributed as an `.xcframework` for easy integration.
- **Cross-Platform Usage**: Suitable for frameworks that don't yet support Swift interfaces.

## Requirements

- **Xcode 15** or later
- **Deployment Target**: iOS 11.0 or later

## Integration

### Adding to your Xcode Project

1. Copy the `KinegramEmrtdConnectorObjC.xcframework` folder into your Xcode project directory.
2. Drag and drop the `.xcframework` folder into your Xcode project.
3. In your target settings:
   - Go to the **General** tab.
   - Under **Frameworks, Libraries, and Embedded Content**, click the `+` button.
   - Select `KinegramEmrtdConnectorObjC.xcframework` and set it to **Embed & Sign**.

### CocoaPods (Optional)

You can also include the Objective-C compatible framework in your project via CocoaPods:

Add the following to your `Podfile`:

```ruby
target 'MyApp' do
  pod 'KinegramEmrtdConnectorObjC'
end
```

Run `pod install` in your project directory.

## Usage in Objective-C

Import the header in your Objective-C files:

```objc
#import <KinegramEmrtdConnectorObjC/KinegramEmrtdConnectorObjC.h>
```

### Interface Overview

The KinegramEMRTDWrapper class provides a simplified interface for interacting with the eMRTD (electronic passports) using Objective-C. The key methods are:

* Initialization

```objc
- (nullable instancetype)initWithClientId:(NSString *)clientId
                             webSocketUrl:(NSString *)url;
```

* Read Passport with MRZ Information
```objc
- (void)readPassportWithDocumentNumber:(NSString *)documentNumber
                           dateOfBirth:(NSString *)dateOfBirth
                          dateOfExpiry:(NSString *)dateOfExpiry
                            completion:(KinegramEMRTDCompletionBlock)completion;
```

Reads the passport using MRZ (Machine Readable Zone) information: documentNumber, dateOfBirth, and dateOfExpiry. The result is returned via the completion block as a JSON string or an error.

* Read Passport with CAN
```objc
- (void)readPassportWithCan:(NSString *)can
                 completion:(KinegramEMRTDCompletionBlock)completion;
```

Reads the passport using the CAN (Card Access Number). The result is returned via the completion block as a JSON string or an error.

### Completion Block

The KinegramEMRTDCompletionBlock is a typedef for a block used in the readPassportWith... methods. It has the following signature:

```objc
typedef void(^KinegramEMRTDCompletionBlock)(NSString * _Nullable passportJson, NSError * _Nullable error);
```

* passportJson: A JSON string representing the passport’s data, or nil if an error occurred.
* error: An NSError object describing the issue, or nil if the operation was successful.

### Example

Below is a simple example of using the connector in Objective-C:

```objc
#import "KinegramEmrtdConnectorObjC/KinegramEMRTDWrapper.h"

// Example usage
@interface ViewController ()
@property KinegramEMRTDWrapper *wrapper;
@end

@implementation ViewController
- (IBAction)buttonTouched:(id)sender {
    _wrapper = [
        [KinegramEMRTDWrapper alloc] initWithClientId:@"example_client"
                                         webSocketUrl:@"wss://kinegramdocval.lkis.de/ws1/validate"
    ];

    [_wrapper readPassportWithCan:@"123465" completion:^(NSString * _Nullable passportJson, NSError * _Nullable error) {
        NSLog(@"passportJson: %@", passportJson);
        NSLog(@"error: %@", error);
    }];
}
@end
```

## Changelog

See the main [Changelog](../CHANGELOG.md) for release notes.

## More Information

For detailed documentation, refer to the [Kinegram eMRTD Connector SDK Documentation](https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios/documentation/kinegramemrtdconnector).

For privacy-related information, see the [Privacy Notice](https://kinegram.digital/privacy-notice/).