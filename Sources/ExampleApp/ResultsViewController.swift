import UIKit
import KinegramEmrtdConnector


class ResultsViewController: UIViewController {
    @IBOutlet private weak var imageViewFacePhoto: UIImageView!
    @IBOutlet private weak var labelEmrtd: UILabel!
    var emrtd: EmrtdPassport?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Results ViewController"

        guard let emrtd = emrtd else {
            labelEmrtd.text = "`emrtd` is unexpectedly nil"
            return
        }
        imageViewFacePhoto.image = UIImage(data: emrtd.facePhoto ?? Data())
        imageViewFacePhoto.layer.borderColor = UIColor.label.cgColor

        var text = ""
        if isExpired(emrtd: emrtd) {
            text += "❌ Document is expired\n\n"
        }
        if emrtd.passiveAuthentication {
            text += "✅ Data Integrity and Authenticity confirmed."
            let aaResult = emrtd.activeAuthenticationResult
            let caResult = emrtd.chipAuthenticationResult
            switch (aaResult, caResult) {
            case (.failed, _), (_, .failed):
                text += "\n\n❌ Chip is cloned."
            case (.success, _), (_, .success):
                text += "\n\n✅ Chip ist not cloned."
            default:
                text += "\n\nChip Clone-Detection is not supported by this eMRTD."
            }
        } else {
            text += "❌ Data Integrity and Authenticity not confirmed."
            if let paDetails = emrtd.passiveAuthenticationDetails {
                text += "\n\n\n\(paDetails.description)"
            }
        }

        if let mrzInfo = emrtd.mrzInfo {
            text += "\n\n\n\(mrzInfo)"
        }
        if !emrtd.errors.isEmpty {
            text += "\n\n\n\(emrtd.errors)"
        }
        labelEmrtd.text = text
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        imageViewFacePhoto.layer.borderColor = UIColor.label.cgColor
    }

    private func isExpired(emrtd: EmrtdPassport) -> Bool {
        guard let mrzInfo = emrtd.mrzInfo else {
            // DocVal Server failed to parse MRZ Info.
            // The `errors` field of EmrtdPassport contains an error string.
            return false
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        if let startDate = Calendar.current.date(byAdding: .year, value: -40, to: Date()) {
            // "yyMMdd" -> The year is only indicated by two characters
            // Currently we have the 30 Nov 2023 -> The `startDate` will be 30 Nov 1983.
            // This means the parsed "yyMMdd" expiry date will be in the interval "30 Nov 1983" to "30 Nov 2083"
            dateFormatter.twoDigitStartDate = startDate
        }
        guard let dateOfExpiry = dateFormatter.date(from: mrzInfo.dateOfExpiry) else {
            print("Date of Expiry is unexpectedly in an invalid format")
            return false
        }
        return dateOfExpiry < Date()
    }
}
