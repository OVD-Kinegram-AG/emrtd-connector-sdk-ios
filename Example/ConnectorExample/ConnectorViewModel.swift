import Foundation
import KinegramEmrtdConnector

@MainActor
class ConnectorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var statusText = "Ready to validate"
    @Published var canNumber = ""
    @Published var documentNumber = ""
    @Published var birthDate = ""
    @Published var expiryDate = ""
    @Published var isValidating = false
    @Published var validationResult: ValidationResult?

    // MARK: - Private Properties
    private var connector: EmrtdConnector?
    private let serverURL = "wss://docval.kurzdigital.com/ws2/validate"
    private let clientId = "example_client" // <-- Replace with your actual client ID
    // If set to false (fire-and-forget), the app will NOT receive/show a ValidationResult
    private let receiveResult = true
    private let monitoringLogger = ConsoleMonitoringLogger()

    // MARK: - Public Methods
    private func connectAndValidate(with accessKey: AccessKey) async {
        debugPrint("🔌 Starting validation process...")
        isValidating = true
        statusText = "Connecting to server..."
        validationResult = nil

        do {
            guard let url = URL(string: serverURL) else {
                debugPrint("❌ Invalid server URL")
                statusText = "Invalid URL"
                isValidating = false
                return
            }

            // Create connector with unique validation ID
            // (This comes normally from your server for internal reference)
            let validationId = UUID().uuidString
            debugPrint("📋 Creating connector with validation ID: \(validationId)")

            connector = EmrtdConnector(
                serverURL: url,
                validationId: validationId,
                clientId: clientId,
                receiveResult: receiveResult
            )

            // Enable monitoring (optional)
            connector?.monitoringDelegate = monitoringLogger

            /*
             Optional configurations:
             
             1. Custom HTTP headers for authentication:
             let myHttpHeaders = [
                 "Authorization": "Bearer your-token"
             ]

             2. Fire-and-forget mode (don't receive result back):
             let receiveResult = false
             
             Example with all options:
             connector = EmrtdConnector(
                 serverURL: url,
                 validationId: validationId,
                 clientId: clientId,
                 httpHeaders: myHttpHeaders,
                 enableDiagnostics: false,
                 receiveResult: false
             )
             */

            // Set delegate
            connector?.delegate = self
            debugPrint("👥 Delegate set")

            debugPrint("🚀 Starting validation...")
            // Default usage: validate with MRZ or CAN; PACE polling remains off unless specified
            let result = try await connector!.validate(with: accessKey)

            // Alternative: Automatic PACE selection based on document info
            // let result = try await connector!.validate(
            //     with: accessKey,
            //     documentType: .idCard,
            //     issuingCountry: "FRA"
            // )
            //
            // Or derive the document type from the MRZ document code prefix (e.g., "ID", "I<", "P<", "PM")
            // let result = try await connector!.validate(
            //     with: accessKey,
            //     documentType: DocumentKind.fromMRZDocumentCode("ID"),
            //     issuingCountry: "FRA"
            // )

            if receiveResult {
                debugPrint("📊 Validation complete")
                debugPrint("  - Status: \(result.status)")
                debugPrint("  - Is Valid: \(result.isValid)")
                if let mrzInfo = result.mrzInfo {
                    debugPrint("  - Name: \(mrzInfo.primaryIdentifier) \(mrzInfo.secondaryIdentifier)")
                    debugPrint("  - Document: \(mrzInfo.documentNumber)")
                }
                validationResult = result
                statusText = "Validation complete"
            } else {
                // Fire-and-forget: do not present a result
                debugPrint("📊 Validation posted (fire-and-forget mode)")
                validationResult = nil
                statusText = "Posted to server"
            }

        } catch {
            debugPrint("❌ Process failed: \(error.localizedDescription)")
            statusText = "Failed: \(error.localizedDescription)"
        }

        isValidating = false
    }

    func validateWithCAN() async {
        debugPrint("🔐 Starting CAN validation...")
        debugPrint("📝 CAN: \(canNumber)")

        // Create CAN access key
        let canKey = CANKey(can: canNumber)
        debugPrint("🔑 Created CAN access key")

        await connectAndValidate(with: canKey)
    }

    func validateWithMRZ() async {
        debugPrint("🔐 Starting MRZ validation...")
        debugPrint("📝 Document Number: \(documentNumber)")
        debugPrint("📝 Birth Date: \(birthDate)")
        debugPrint("📝 Expiry Date: \(expiryDate)")

        // Create MRZ access key
        let mrzKey = MRZKey(
            documentNumber: documentNumber,
            birthDateyyMMdd: birthDate,
            expiryDateyyMMdd: expiryDate
        )
        debugPrint("🔑 Created MRZ access key")

        await connectAndValidate(with: mrzKey)
    }

    // MARK: - Computed Properties

    var canButtonDisabled: Bool {
        isValidating || !isCANValid
    }

    var mrzButtonDisabled: Bool {
        isValidating || !isMRZValid
    }

    var isCANValid: Bool {
        canNumber.count == 6 && canNumber.allSatisfy { $0.isNumber }
    }

    var isMRZValid: Bool {
        !documentNumber.isEmpty &&
        birthDate.count == 6 && birthDate.allSatisfy { $0.isNumber } &&
        expiryDate.count == 6 && expiryDate.allSatisfy { $0.isNumber }
    }

}

// MARK: - EmrtdConnectorDelegate
extension ConnectorViewModel: EmrtdConnectorDelegate {
    func connectorDidConnect(_ connector: EmrtdConnector) async {
        debugPrint("📡 Delegate: Connected to server")
        statusText = "Connected - Place document on phone"
    }

    func connectorDidDisconnect(_ connector: EmrtdConnector) async {
        debugPrint("📡 Delegate: Disconnected from server")
        statusText = "Ready to validate"
        self.connector = nil
    }

    func connectorWillReadChip(_ connector: EmrtdConnector) async {
        debugPrint("📡 Delegate: Starting chip read")
        statusText = "Reading chip... Hold document steady"
    }

    func connectorDidPerformHandover(_ connector: EmrtdConnector) async {
        debugPrint("📡 Delegate: Handover performed - authenticating with server")
        statusText = "Authenticating with server..."
    }

    func connectorDidSuccessfullyPostToServer(_ connector: EmrtdConnector) async {
        debugPrint("✅ Delegate: Server successfully posted results (Close Code 1000)")
        // This confirms the server has successfully processed and posted the validation
        // Especially useful when using receiveResult: false
        if !receiveResult {
            statusText = "Server posted results"
            isValidating = false
        }
    }

    func connector(_ connector: EmrtdConnector, didFailWithError error: Error) async {
        debugPrint("📡 Delegate: \(error.localizedDescription)")
        statusText = "Delegate: \(error.localizedDescription)"
        isValidating = false
        // Do not call disconnect() here; validate() handles cleanup on error
        self.connector = nil
    }

    func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {
        debugPrint("📱 NFC Status: \(status.step) - \(status.alertMessage)")

        // The NFC reader session is managed internally by KinegramEmrtd
        // This status update is automatically applied to the session's alertMessage
        // through the localization callbacks we configured

        // Update our UI status text as well
        statusText = status.alertMessage
    }
}
