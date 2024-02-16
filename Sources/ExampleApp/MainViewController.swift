import UIKit
import CoreNFC
import KinegramEmrtdConnector

class MainViewController: UIViewController {
    // URL of the DocVal Service API Endpoint.
    private let url = "wss://kinegramdocval.lkis.de/ws1/validate"
    // Client ID Functions as an API Access key.
    private let clientId = "example_client"
    private lazy var emrtdConnector: EmrtdConnector? = {
        EmrtdConnector(clientId: clientId, webSocketUrl: url, delegate: self)
    }()
    @IBOutlet private weak var textfieldDocumentNumber: UITextField!
    @IBOutlet private weak var textfieldDateOfBirth: UITextField!
    @IBOutlet private weak var textfieldDateOfExpiry: UITextField!
    @IBOutlet private weak var textfieldCan: UITextField!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var labelNFCTagReaderError: UILabel!
    @IBOutlet private weak var labelEmrtdConnectorError: UILabel!
    @IBOutlet private weak var buttonShowResults: UIButton!
    @IBOutlet private weak var labelURL: UILabel!

    private var accessChipType: AccessChipType?
    private var nfcReaderSession: NFCReaderSessionProtocol?
    private var emrtd: EmrtdPassport?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Main ViewController"
        textfieldDocumentNumber.text = UserDefaults.standard.string(forKey: "documentNumber") ?? ""
        textfieldDateOfBirth.text = UserDefaults.standard.string(forKey: "dateOfBirth") ?? ""
        textfieldDateOfExpiry.text = UserDefaults.standard.string(forKey: "dateOfExpiry") ?? ""
        textfieldCan.text = UserDefaults.standard.string(forKey: "can") ?? ""
        labelURL.text = url

        if !NFCTagReaderSession.readingAvailable {
            labelNFCTagReaderError.text =
                """
                NFCTagReaderSession reading not available!
                Have you configured your app to detect NFC Tags (Info.plist)?
                Have you added the capability "Near Field Communication Tag Reading"?
                Does this device support NFC?
                Does this device run on iOS 13.0 or later?
                """
        }
        if self.emrtdConnector == nil {
            labelEmrtdConnectorError.text =
                """
                EmrtdConnector not initialized.
                Verify that the specified URL is correct.
                """
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let resultsViewController = segue.destination as? ResultsViewController {
            resultsViewController.emrtd = emrtd
            buttonShowResults.isHidden = true
            emrtd = nil
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveToUserDefaults()
    }

    @IBAction func accessChipUsingMRZInfo(_ sender: Any) {
        textfieldDocumentNumber.text = (textfieldDocumentNumber.text ?? "").uppercased()
        accessChipType = .mrzInfo(
            docNumber: textfieldDocumentNumber.text ?? "",
            dateOfBirth: textfieldDateOfBirth.text ?? "",
            dateOfExpiry: textfieldDateOfExpiry.text ?? ""
        )
        accessChip()
    }

    @IBAction func accessChipUsingCAN(_ sender: Any) {
        accessChipType = .can(textfieldCan.text ?? "")
        accessChip()
    }

    private func accessChip() {
        view.endEditing(true) // Hide keyboard
        saveToUserDefaults()
        activityIndicator.startAnimating()
        guard let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: .main) else {
            labelNFCTagReaderError.text = "Failed to initialize NFC Reader session!"
            return
        }
        session.alertMessage = "Hold eMRTD to Phone"
        session.begin()
    }

    private func saveToUserDefaults() {
        UserDefaults.standard.set(textfieldDocumentNumber.text ?? "", forKey: "documentNumber")
        UserDefaults.standard.set(textfieldDateOfBirth.text ?? "", forKey: "dateOfBirth")
        UserDefaults.standard.set(textfieldDateOfExpiry.text ?? "", forKey: "dateOfExpiry")
        UserDefaults.standard.set(textfieldCan.text ?? "", forKey: "can")
    }

    private enum AccessChipType {
        case can(String)
        case mrzInfo(docNumber: String, dateOfBirth: String, dateOfExpiry: String)
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension MainViewController: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        labelNFCTagReaderError.text = ""
        labelEmrtdConnectorError.text = ""
        buttonShowResults.isHidden = true
        // NFC Reader Session is now active
        // It's useful to hold a reference to the NFC Reader Session.
        self.nfcReaderSession = session
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.nfcReaderSession = nil
        if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled {
            // Notify user about the error that occurred
            labelNFCTagReaderError.text = error.localizedDescription
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let emrtdConnector = self.emrtdConnector else {
            fatalError("EmrtdConnector unexpectedly nil")
        }
        guard tags.count == 1, let tag = tags.first else {
            session.invalidate(errorMessage: "More than one tag found")
            return
        }
        guard case let .iso7816(emrtdTag) = tag else {
            session.invalidate(errorMessage: "Non ISO7816 tag found")
            return
        }

        session.connect(to: tag) { error in
            guard error == nil else {
                session.invalidate(errorMessage: "Failed to connect to tag")
                return
            }
            // Successfully connected to the tag

            let vId = UUID().uuidString
            switch self.accessChipType {
            case .can(let can):
                emrtdConnector.connect(to: emrtdTag, vId: vId, can: can)
            case .mrzInfo(let docNumber, let dateOfBirth, let dateOfExpiry):
                emrtdConnector.connect(to: emrtdTag, vId: vId, documentNumber: docNumber,
                                       dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
            case .none:
                fatalError("No Access Chip Type set")
            }
        }
    }
}

// MARK: - EmrtdConnectorDelegate

extension MainViewController: EmrtdConnectorDelegate {
    func shouldRequestEmrtdPassport() -> Bool {
        true
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didUpdateStatus status: EmrtdConnector.Status) {
        // Update the message of the NFC reader session alert.
        nfcReaderSession?.alertMessage = status.description
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didReceiveEmrtdPassport emrtd: EmrtdPassport?) {
        guard let emrtd = emrtd else {
            self.emrtd = nil
            labelEmrtdConnectorError.text = "Failed to decode EmrtdPassport\n"
            return
        }
        print(emrtd)
        self.emrtd = emrtd
        buttonShowResults.isHidden = false
    }

    func emrtdConnector(_ emrtdConnector: EmrtdConnector,
                        didCloseWithCloseCode closeCode: Int,
                        reason: EmrtdConnector.CloseReason?) {
        activityIndicator.stopAnimating()
        if closeCode != 1_000 {
            let text = "\(closeCode) \(reason?.description ?? "")"
            labelEmrtdConnectorError.text = (labelEmrtdConnectorError.text ?? "") + text
            // Also show a message in the nfc sheet
            nfcReaderSession?.invalidate(errorMessage: "\(text.prefix(64))")
        }
    }
}
