# Connect to an ICAO eMRTD NFC TAG

Connect to a [NFCISO7816Tag][nfc_iso_7816_tag] using the [Core NFC][core_nfc] framework. 

## Configure Your App to Detect NFC Tags

See also section "**Configure the App to Detect NFC Tags**" in the
[Building an NFC Tag-Reader App][apple_build_nfc_tag_reader_app_configure] Documentation from Apple.

### 1. Changes in Info.plist

- The application needs to define the list of `application IDs` or `AIDs` it can connect to,
in the `Info.plist` file.
The `AID` is a way of uniquely identifying an application on an ISO 7816 tag. 
ICAO Passports use the AID `A0000002471001`.
After adding the list of supported AIDs, the *Info.plist* entry should look like this:

```xml
  <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
  <array>
    <string>A0000002471001</string>
  </array>
```

- The `Info.plist` also needs to include a privacy description for NFC usage,
using the `NFCReaderUsageDescription` key:

```xml
  <key>NFCReaderUsageDescription</key>
  <string>This app uses NFC to scan passports</string>
```

### 2. Entitlement

- Add a new entitlement for reading NFC, available since iOS 13.
This new entitlement is added automatically by Xcode when enabling the **Near Field Communication
Tag Reading** capability in the target **Signing & Capabilities**.
After enabling the capability the \*.entitelments file needs to contain the `TAG` format:

```xml
...
<dict>
  <key>com.apple.developer.nfc.readersession.formats</key>
  <array>
    <string>TAG</string> // Application specific tag, including ISO 7816 Tags
  </array>
</dict>
...
 ```

## Connect to a NFCISO7816Tag

Connect to a [NFCISO7816Tag][nfc_iso_7816_tag] using the [Core NFC][core_nfc] framework as explained 
by Apple in their [Building an NFC Tag-Reader App][apple_build_nfc_tag_reader_app_start] documentation.

In the following Example the NFCTagReaderSessionDelegate is implemented. The function 
**beginNFCSession()** in this example can be used to begin a new NFC Session and bring up the 
NFC Session Alert.


```swift
import CoreNFC

class MainViewController: UIViewController {
    private var nfcReaderSession: NFCReaderSessionProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Check wether NFC functionality is available
        if !NFCTagReaderSession.readingAvailable {
            // NFCTagReaderSession reading not available!
            // Have you configured your app to detect NFC Tags (Info.plist)?
            // Have you added the capability "Near Field Communication Tag Reading"?
            // Does this device support NFC?
            // Does this device run iOS 13.0 or later?
            print("NFC functionality not available")
        }
    }
    
    private func beginNFCSession() {
        // Note: For PACE-enabled IDs (e.g., FRA/OMN), start with `.pace` (iOS 16+)
        // and ensure the PACE entitlement is present. `.pace` is exclusive and
        // cannot be combined with other polling options.
        let requiresPACE = false // set to true for PACE-enabled IDs in your app
        if #available(iOS 16.0, *), requiresPACE {
            guard let session = NFCTagReaderSession(pollingOption: .pace,
                                                    delegate: self, queue: .main) else {
                print("Failed to initialize NFC Reader session!")
                return
            }
            session.alertMessage = "Hold Document to Phone"
            session.begin()
        } else {
            guard let session = NFCTagReaderSession(pollingOption: [.iso14443],
                                                    delegate: self, queue: .main) else {
                print("Failed to initialize NFC Reader session!")
                return
            }
            session.alertMessage = "Hold Passport to Phone"
            session.begin()
        }
    }
}

extension MainViewController: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // NFC Reader Session is now active
        // It's useful to hold a reference to the NFC Reader Session
        self.nfcReaderSession = session

        // You can then later update the message in the NFC Session alert:
        // self.nfcReaderSession.alertMessage = "Something"
    }

    func tagReaderSession(_ session: NFCTagReaderSession,
                          didInvalidateWithError error: Error) {
        self.nfcReaderSession = nil // Session is now invalidated
        if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled {
            // Notify user about the error that occurred
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.invalidate(errorMessage: "More than one tag found")
            return
        }
        guard case let .iso7816(passportTag) = tag else {
            session.invalidate(errorMessage: "Non ISO7816 tag found")
            return
        }
        session.connect(to: tag) { error in
            guard error == nil else {
                session.invalidate(errorMessage: "Failed to connect to tag")
                return
            }
            print("Successfully connected to an ISO7816 tag", passportTag)
            ...
        }
    }
}
```

[nfc_iso_7816_tag]: https://developer.apple.com/documentation/corenfc/nfciso7816tag
[core_nfc]: https://developer.apple.com/documentation/corenfc
[apple_build_nfc_tag_reader_app_configure]: https://developer.apple.com/documentation/corenfc/building_an_nfc_tag-reader_app#3240401
[apple_build_nfc_tag_reader_app_start]: https://developer.apple.com/documentation/corenfc/building_an_nfc_tag-reader_app#3240402
