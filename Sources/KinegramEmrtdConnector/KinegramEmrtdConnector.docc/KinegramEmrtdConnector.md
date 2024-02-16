# ``KinegramEmrtdConnector``

Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD via a WebSocket
connection.

The DocVal server is able to read the data (like MRZ info or photo of face) and verify the
authenticity and integrity of the data.

If the eMRTD supports the required protocols, the DocVal Server will additionally be able to verify
that the chip was not cloned.

The DocVal Server will post the result to your **Result-Server**.

## Requirements

ℹ️ You **must** provide either the **card access number (CAN)** _or_ the **document number**, the
**date of birth** and the **date of expiry** to access the eMRTD.
Refer to [ICAO Doc 9303 **Part 4**][icao9303].

## Usage Example

1️⃣ Connect to an ICAO eMRTD NFC TAG
See the article <doc:ConnectToEmrtdTag> on how to connect to an ICAO eMRTD NFC Tag.

2️⃣ Enable the DocVal Server to access the eMRTD via an
EmrtdConnector instance as shown below.

💡 <doc:KinegramEmrtdConnector#Module-was-renamed-to-KinegramEmrtdConnector>

```swift
import UIKit
import CoreNFC
import KinegramEmrtdConnector

class MainViewController: UIViewController {
    // Client ID Functions as an API Access key.
    private let clientId = "example_client"
    // URL of the DocVal Service API Endpoint.
    private let url = "wss://kinegramdocval.lkis.de/ws1/validate"

    private lazy var emrtdConnector: EmrtdConnector? = {
        EmrtdConnector(clientId: clientId, webSocketUrl: url, delegate: self)
    }()
    
    ...

    func connect() {
        // NFCISO7816Tag acquired from iOS. See article `Connect to an ICAO eMRTD NFC TAG`.
        let emrtdTag: NFCISO7816Tag

        // Unique transaction ID, usually from your Server
        let validationId = UUID().uuidString

        // Access Key values from the MRZ; Date format: yyMMDD
        emrtdConnector.connect(to: emrtdTag, vId: validationId, documentNumber:  "123465789",
                               dateOfBirth: "970101", dateOfExpiry: "251008")
    }
}

extension MainViewController: EmrtdConnectorDelegate {
    func shouldRequestEmrtdPassport() -> Bool {
        // Wether the Emrtd Connector should request the result from the DocVal Server.
        // Return true or false respectively.
        true
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didUpdateStatus status: EmrtdConnector.Status) {
        // If you hold a reference to the NFC reader session you can update
        // the message of the NFC reader session alert:
        self.nfcReaderSession.alertMessage = status.description
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didReceiveEmrtdPassport emrtdPassport: EmrtdPassport?) {
        print(emrtdPassport)
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector,
                        didCloseWithCloseCode closeCode: Int,
                        reason: EmrtdConnector.CloseReason?) {
        if closeCode != 1_000 {
            print("Session closed.")
        } else {
            print("Session closed because of a problem. Reason: \(reason?.description ?? "")")
        }
    }
}
```

## Session Close Reason values

Read more about the possible Close Reason values in the ``EmrtdConnector/CloseReason`` documentation.

## eMRTD Session Status values

Read more about the possible Status values in the ``EmrtdConnector/Status`` documentation.

## Module was renamed to KinegramEmrtdConnector

⚠ The module **KTAKinegramEmrtdConnector** was renamed to **KinegramEmrtdConnector**. 
Adjust your existing code accordingly as you upgrade to the new **KinegramEmrtdConnector.xcframework**.

Version 0.0.9 and before:

```swift
import KTAKinegramEmrtdConnector
```

Now:

```swift
import KinegramEmrtdConnector
```

## Limitations

The NFC Session duration is limited by apple to 20 seconds. Because of that, a stable internet
connection is required. You may recommend the enduser to use a WIFI connection preferably.

If the Session Timeout is reached, the `tagReaderSession(session:,didInvalidateWithError:)` delegate
function of your NFCTagReaderSessionDelegate will be called.

[icao9303]: https://www.icao.int/publications/pages/publication.aspx?docnum=9303
