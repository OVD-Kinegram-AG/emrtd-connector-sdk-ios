import Foundation
import KinegramEmrtd

// Using APDURelayHandler from KinegramEmrtd framework

/// Coordinates the entire WebSocket session and protocol flow
actor WebSocketSessionCoordinator {
    private let connection: WebSocketConnection
    private let messageHandler = WebSocketMessageHandler()
    private let stateMachine = ProtocolStateMachine()

    private let validationId: String
    private let clientId: String
    private let enableDiagnostics: Bool
    private let receiveResult: Bool
    private var sessionId: String?

    // MARK: - Chip Session Management

    /// EmrtdReader instance management
    private var emrtdReader: EmrtdReader?

    /// Store the current reader instance for external APDU forwarding
    private var currentReader: EmrtdReader?

    /// Pending binary files that must be sent before CA_HANDOVER
    private var pendingBinaryFiles: [String: Data] = [:]

    /// Active continuation for protocol flow
    private var activeContinuation: CheckedContinuation<SessionResult, Error>?

    /// Accept message continuation
    private var acceptContinuation: CheckedContinuation<AcceptMessage, Error>?

    /// Handback continuation
    private var handbackContinuation: CheckedContinuation<CAHandbackMessage, Error>?

    /// Result continuation
    private var resultContinuation: CheckedContinuation<ValidationResult, Error>?

    /// Received messages buffer
    private var messageBuffer: [ParsedMessage] = []

    /// APDU response continuation for relay
    private var apduResponseContinuation: CheckedContinuation<Data, Error>?

    /// Track sent and received files to prevent duplicates
    private var sentFiles: Set<String> = []
    private var receivedFiles: Set<String> = []

    /// Track if we've received a CLOSE message with error details
    private var closeError: Error?

    /// Track if we've already notified about an error
    private var errorNotified = false

    /// Active NFC reading task to allow cancellation
    private var nfcReadingTask: Task<ChipReadingResult, Error>?

    /// NFC status callback
    private var onNFCStatusUpdate: ((NFCProgressStatus) -> Void)?

    /// NFC status localization callback
    private var nfcStatusLocalization: ((NFCProgressStatus) -> String)?

    /// Error callback
    private var onError: ((Error) -> Void)?

    /// Success post callback for Close Code 1000
    private var onSuccessfulPost: (() -> Void)?

    /// Monitoring delegate from the parent connector
    private weak var monitoringDelegate: MonitoringDelegate?

    init(
        connection: WebSocketConnection,
        validationId: String,
        clientId: String,
        enableDiagnostics: Bool = false,
        receiveResult: Bool = true,
        nfcStatusCallback: ((NFCProgressStatus) -> Void)? = nil,
        nfcStatusLocalization: ((NFCProgressStatus) -> String)? = nil,
        errorCallback: ((Error) -> Void)? = nil,
        successfulPostCallback: (() -> Void)? = nil,
        monitoringDelegate: MonitoringDelegate? = nil
    ) {
        self.connection = connection
        self.validationId = validationId
        self.clientId = clientId
        self.enableDiagnostics = enableDiagnostics
        self.receiveResult = receiveResult
        self.onNFCStatusUpdate = nfcStatusCallback
        self.nfcStatusLocalization = nfcStatusLocalization
        self.onError = errorCallback
        self.onSuccessfulPost = successfulPostCallback
        self.monitoringDelegate = monitoringDelegate

        setupConnectionHandlers()
    }

    // MARK: - Public Methods

    // MARK: - Chip Session Management Methods

    /// Initialize the reader (threading is now handled internally by KinegramEmrtd)
    private func ensureReader() async -> EmrtdReader {
        if let reader = emrtdReader {
            return reader
        }

        // Capture callbacks in a non-isolated way
        let statusCallback = self.onNFCStatusUpdate
        let localizationCallback = self.nfcStatusLocalization

        // Create reader with custom localizations that trigger our NFC status updates
        let reader = EmrtdReader(
            errorLocalization: { error in
                // Convert error to NFCProgressStatus for consistent handling
                let errorMessage: String

                // Get a user-friendly error message
                switch error {
                case .IncorrectAccessKey(let remainingAttempts):
                    if remainingAttempts > 0 {
                        errorMessage = "Incorrect access key. \(remainingAttempts) attempts remaining"
                    } else {
                        errorMessage = "Incorrect access key. Document may be blocked"
                    }
                case .ConnectionLost:
                    errorMessage = "Connection lost - please hold document steady"
                case .PaceOrBacFailed:
                    errorMessage = "Authentication failed - check access key"
                case .FileReadFailed:
                    errorMessage = "Failed to read document data"
                default:
                    // Use default localization for other errors
                    errorMessage = ErrorLocalizer.localizedMessage(for: error)
                }

                // Create an error status
                let errorStatus = NFCProgressStatus.error(errorMessage)

                // Trigger our callback
                statusCallback?(errorStatus)

                // Use custom localization if provided, otherwise return the error message
                // This allows the app to control what appears in the NFC sheet on errors
                if let customMessage = localizationCallback?(errorStatus) {
                    return customMessage
                } else {
                    return errorMessage
                }
            },
            stepLocalization: { step in
                // Map ReadAndVerifyStep to our NFCProgressStatus
                let nfcStatus: NFCProgressStatus
                switch step {
                case .waitingForPassport:
                    nfcStatus = .waitingForPassport
                case .readFileAtrInfo, .readFileCardAccess:
                    nfcStatus = .connecting
                case .doPaceOrBac:
                    nfcStatus = NFCProgressStatus(step: .performingAccessControl)
                case .readFileSOD:
                    nfcStatus = NFCProgressStatus(step: .readingSOD)
                case .readFileDG14:
                    nfcStatus = NFCProgressStatus(step: .readingDG14)
                case .doChipAuthenticationIfAvailable:
                    nfcStatus = NFCProgressStatus(step: .performingCA)
                case .readFileDG15:
                    nfcStatus = NFCProgressStatus(step: .readingDG15)
                case .doActiveAuthentication:
                    nfcStatus = NFCProgressStatus(step: .performingAA)
                case .readRemainingElementaryFiles:
                    // This covers reading DG1, DG2, DG7, DG11, DG12
                    nfcStatus = NFCProgressStatus(step: .readingDG1)
                case .readFile(let fileName):
                    // Handle specific file reading
                    switch fileName {
                    case .DG1:
                        nfcStatus = NFCProgressStatus(step: .readingDG1)
                    case .DG2:
                        nfcStatus = NFCProgressStatus(step: .readingDG2(progress: 0))
                    case .DG7:
                        nfcStatus = NFCProgressStatus(step: .readingDG7)
                    case .DG11:
                        nfcStatus = NFCProgressStatus(step: .readingDG11)
                    case .DG12:
                        nfcStatus = NFCProgressStatus(step: .readingDG12)
                    default:
                        nfcStatus = NFCProgressStatus(step: .readingDG1)
                    }
                case .doPassiveAuthentication:
                    // Don't change status here - we'll set .done after validation
                    nfcStatus = NFCProgressStatus(step: .validatingWithServer)
                case .done:
                    // This might not be reached if session closes early
                    nfcStatus = .done
                default:
                    // For other steps, use current status
                    return step.description
                }

                // Trigger our callback
                statusCallback?(nfcStatus)

                // Return the alert message for the NFC dialog
                // Use custom localization if provided, otherwise use default English
                if let customMessage = localizationCallback?(nfcStatus) {
                    return customMessage
                } else {
                    return nfcStatus.alertMessage
                }
            },
            fileReadProgressLocalization: { fileName, readBytes, totalBytes in
                // Create status for file progress
                let status = NFCProgressStatus.fileProgress(
                    fileName: fileName,
                    readBytes: readBytes,
                    totalBytes: totalBytes
                )

                // Trigger our callback
                statusCallback?(status)

                // Return the alert message for the NFC dialog
                // Use custom localization if provided, otherwise use default English
                if let customMessage = localizationCallback?(status) {
                    return customMessage
                } else {
                    return status.alertMessage
                }
            }
        )

        // Set monitoring delegate if available
        if let monitoringDelegate = self.monitoringDelegate {
            reader.setMonitoringDelegate(monitoringDelegate)
        }

        self.emrtdReader = reader
        return reader
    }

    /// Get pending binary files that must be sent before CA_HANDOVER
    func getPendingBinaryFiles() -> [String: Data] {
        return pendingBinaryFiles
    }

    /// Forward APDU command from server to chip during CA phase
    func forwardAPDUCommand(_ command: Data) async throws -> Data {
        guard let reader = currentReader else {
            throw EmrtdConnectorError.invalidState(
                current: "no active reader",
                expected: "active reader during CA"
            )
        }

        return try await reader.sendExternalAPDU(command)
    }

    /// Clear the current reader reference (e.g., on error or disconnect)
    func clearReaderReference() {
        self.currentReader = nil
        Logger.debug("Cleared reader reference")
    }

    /// Close the NFC session after CA phase (for errors/timeouts)
    func closeNFCSession() async {
        // IMMEDIATELY invalidate the session to interrupt startWithHandover
        if let reader = currentReader {
            reader.invalidateSession(errorMessage: "Connection timed out")
            Logger.debug("Invalidated NFC session")
        } else if let reader = emrtdReader {
            reader.invalidateSession(errorMessage: "Connection timed out")
            Logger.debug("Invalidated NFC session via emrtdReader")
        }

        // Then cancel the task
        if let task = nfcReadingTask {
            task.cancel()
            Logger.debug("Cancelled NFC reading task")

            // Give it a moment to clean up
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            nfcReadingTask = nil
        }

        self.currentReader = nil
    }

    /// Close the NFC session with success indication
    /// Should be called AFTER all status updates (including .done) have been sent
    func closeNFCSessionWithSuccess() async {
        if let reader = currentReader {
            reader.closeSession()  // This shows success checkmark
            Logger.debug("Closed NFC session with success")
        } else if let reader = emrtdReader {
            reader.closeSession()  // This shows success checkmark
            Logger.debug("Closed NFC session with success via emrtdReader")
        }

        self.currentReader = nil
    }

    /// Manually update NFC status and trigger both callbacks
    /// This is needed when we want to ensure a status update is sent even after NFC session might be closed
    func updateNFCStatus(_ status: NFCProgressStatus) async {
        // Trigger the status callback (for delegate)
        onNFCStatusUpdate?(status)

        // Also trigger the localization callback (for NFC dialog)
        // This ensures the NFC dialog text is updated even if the session is closing
        if let localization = nfcStatusLocalization {
            _ = localization(status)
        }

        // Give the NFC dialog a moment to update
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    /// Performs chip reading with handover support
    func performChipReading(
        accessKey: AccessKey,
        activeAuthChallenge: Data?,
        usePACEPolling: Bool = false
    ) async throws -> ChipReadingResult {

        // Cancel any existing NFC reading task
        nfcReadingTask?.cancel()

        // Create a new task for NFC reading with proper timeout handling
        let task = Task<ChipReadingResult, Error> {
            // Ensure reader is initialized
            let reader = await ensureReader()

            // Store the current reader instance for external APDU forwarding
            self.currentReader = reader

            // Check for cancellation before starting
            try Task.checkCancellation()

            // Ensure the NFC session is invalidated if this task is cancelled while awaiting
            // the underlying SDK call, to avoid leaking continuations inside the SDK.
            do {
                let handoverState = try await withTaskCancellationHandler(operation: {
                    try await reader.startWithHandover(
                        accessKey: accessKey,
                        activeAuthChallenge: activeAuthChallenge,
                        apduRelayHandler: nil,
                        usePACEPolling: usePACEPolling
                    )
                }, onCancel: {
                    reader.invalidateSession(errorMessage: "Operation cancelled")
                })

                // Check for cancellation after NFC operation
                try Task.checkCancellation()

                // Convert to handover data for WebSocket
                let handoverData = createHandoverData(from: handoverState)

                return ChipReadingResult(
                    handoverState: handoverState,
                    handoverData: handoverData
                )
            } catch {
                // On any error (including cancellation), ensure session is properly closed
                Logger.debug("NFC operation error: \(error)")
                reader.invalidateSession(errorMessage: "Connection timed out")
                throw error
            }
        }

        // Store the task for cancellation
        nfcReadingTask = task

        do {
            let result = try await task.value
            nfcReadingTask = nil
            return result
        } catch {
            nfcReadingTask = nil
            throw error
        }
    }

    /// Complete chip reading after handback
    func completeChipReading(
        handoverState: HandoverState,
        handbackInfo: CAHandbackInfo,
        filesToRead: DataGroupSet,
        usePACEPolling: Bool = false
    ) async throws -> CompleteReadingResult {

        // Ensure reader is available
        guard let reader = emrtdReader else {
            throw EmrtdConnectorError.invalidState(
                current: "no reader",
                expected: "initialized reader"
            )
        }

        // Complete reading with server response
        // KinegramEmrtd now handles threading internally
        // IMPORTANT: We disable auto-invalidation to control session ending ourselves
        let result = try await reader.continueAfterHandback(
            from: handoverState,
            handbackInfo: handbackInfo,
            filesToRead: filesToRead,
            shouldAutoInvalidateSession: false,  // We'll control the session ending
            usePACEPolling: usePACEPolling
        )

        // Validate that all required files were read
        do {
            try validateRequiredFiles(result: result, requestedFiles: filesToRead)

            // Update to Done status IMMEDIATELY after successful validation
            // This ensures the user sees "Done" before the session closes
            // Use synchronous update to ensure it happens before session closes
            onNFCStatusUpdate?(.done)
            if let localization = nfcStatusLocalization {
                _ = localization(.done)
            }

            // Give the NFC dialog a brief moment to update
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Now close the session with success indication
            reader.closeSession()
        } catch {
            // Invalidate the session with error message to prevent success checkmark
            reader.invalidateSession(errorMessage: "Reading incomplete - please try again")
            // Re-throw the error after invalidating
            throw error
        }

        // Convert result to our format
        let files = extractFilesFromResult(result)

        // Progress is reported via NFC status updates

        let finishData = createFinishData(from: files, result: result)

        // Clear the reader reference after completing the session
        self.currentReader = nil

        return CompleteReadingResult(
            emrtdResult: files,
            finishData: finishData
        )
    }

    /// Complete chip reading without CA (when no DG14 is present)
    func completeChipReadingWithoutCA(
        handoverState: HandoverState,
        filesToRead: DataGroupSet,
        usePACEPolling: Bool = false
    ) async throws -> CompleteReadingResult {

        // Ensure reader is available
        guard let reader = emrtdReader else {
            throw EmrtdConnectorError.invalidState(
                current: "no reader",
                expected: "initialized reader"
            )
        }

        // When no CA is performed, we need to continue reading with the existing secure messaging
        // The handoverState already contains the secure messaging info from BAC/PACE

        // Use the existing secure messaging from the handover state
        let existingSecureMessaging = handoverState.secureMessagingInfo

        // Create a handback info that preserves the existing secure messaging
        let noCAHandbackMessage = CAHandbackMessage(
            checkResult: CACheckResult.unavailable.rawValue,
            secureMessagingInfo: existingSecureMessaging, // Keep existing SM
            dg1Data: nil,
            errorMessage: nil
        )

        // Convert to KinegramEmrtd type
        let noCAHandbackInfo = KinegramEmrtd.CAHandbackInfo(from: noCAHandbackMessage)

        // Continue reading without CA changes - the reader will use the existing SM
        // IMPORTANT: We disable auto-invalidation to control session ending ourselves
        let result = try await reader.continueAfterHandback(
            from: handoverState,
            handbackInfo: noCAHandbackInfo,
            filesToRead: filesToRead,
            shouldAutoInvalidateSession: false,  // We'll control the session ending
            usePACEPolling: usePACEPolling
        )

        // Validate that all required files were read
        do {
            try validateRequiredFiles(result: result, requestedFiles: filesToRead)

            // Update to Done status IMMEDIATELY after successful validation
            // This ensures the user sees "Done" before the session closes
            // Use synchronous update to ensure it happens before session closes
            onNFCStatusUpdate?(.done)
            if let localization = nfcStatusLocalization {
                _ = localization(.done)
            }

            // Give the NFC dialog a brief moment to update
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Now close the session with success indication
            reader.closeSession()
        } catch {
            // Invalidate the session with error message to prevent success checkmark
            reader.invalidateSession(errorMessage: "Reading incomplete - please try again")
            // Re-throw the error after invalidating
            throw error
        }

        // Convert result to our format
        let files = extractFilesFromResult(result)
        let finishData = createFinishData(from: files, result: result)

        // Clear the reader reference after completing the session
        self.currentReader = nil

        return CompleteReadingResult(
            emrtdResult: files,
            finishData: finishData
        )
    }

    // MARK: - Original Public Methods

    /// Send APDU command and wait for response
    func sendAPDUCommand(_ command: Data) async throws -> Data {
        // Send APDU command as binary message
        let apduMessage = BinaryAPDUMessage(data: command)
        try await connection.send(data: apduMessage.encode())

        // Wait for APDU response
        return try await withCheckedThrowingContinuation { continuation in
            self.apduResponseContinuation = continuation
        }
    }

    /// Send START message and wait for ACCEPT
    func sendStartAndWaitForAccept() async throws -> AcceptMessage {
        // Ensure we're in connected state
        let currentState = await stateMachine.currentState
        if currentState == .initial {
            try await stateMachine.transition(to: .connected)
        }

        // Send START message
        let startMessage = StartMessage(
            validationId: validationId,
            clientId: clientId,
            enableDiagnostics: enableDiagnostics
        )

        try await connection.send(message: startMessage)
        try await stateMachine.transition(to: .started)

        // Wait for ACCEPT message
        return try await withCheckedThrowingContinuation { continuation in
            self.acceptContinuation = continuation
        }
    }

    /// Wait for CA handback message
    func waitForHandback() async throws -> CAHandbackMessage {
        return try await withCheckedThrowingContinuation { continuation in
            self.handbackContinuation = continuation
        }
    }

    /// Wait for RESULT message
    func waitForResult() async throws -> ValidationResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation
        }
    }

    /// Send monitoring message to server
    func sendMonitoringMessage(_ message: String) async {
        // Only send if diagnostics are enabled
        guard enableDiagnostics else {
            return
        }

        let monitoringMessage = MonitoringMessage(message: message)

        do {
            try await connection.send(message: monitoringMessage)
            Logger.debug("Sent monitoring message: \(message)")
        } catch {
            Logger.debug("Failed to send monitoring message: \(error)")
        }
    }

    /// Wait for session to close after receiving result
    func waitForClose(timeout: TimeInterval = 5.0) async {
        // Only wait after result to allow server to send CLOSE
        guard await stateMachine.currentState == .completed else { return }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await stateMachine.currentState == .closed { return }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        // Timed out waiting for CLOSE; continue cleanup
    }

    /// Transition to reading chip state
    func transitionToReadingChip() async throws {
        try await stateMachine.transition(to: .readingChip)
    }

    /// Send CA handover data
    func sendHandover(_ handoverData: HandoverData, handoverState: HandoverState) async throws {
        try await stateMachine.validateMessageSend(.caHandover)

        // Use values from HandoverState
        let message = CAHandoverMessage(
            maxTransceiveLengthForSecureMessaging: handoverState.maxTransceiveLength,
            maxBlockSize: handoverState.maxBlockSize,
            secureMessagingInfo: handoverData.secureMessagingInfo
        )

        try await connection.send(message: message)
        try await stateMachine.transition(to: .handoverSent)
    }

    /// Send finish data with all files
    func sendFinish(_ finishData: FinishData) async throws {
        try await stateMachine.validateMessageSend(.finish)

        // First send all files as binary messages
        for (fileId, fileData) in finishData.filesRead {
            if let data = Data(base64Encoded: fileData) {
                try await sendBinaryFile(fileId: fileId, data: data)
            }
        }

        // Send binary files that were already in binary format
        for (fileId, fileData) in finishData.binaryFiles {
            try await sendBinaryFile(fileId: fileId, data: fileData)
        }

        // Then send FINISH message
        let message = FinishMessage(
            sendResult: receiveResult,
            activeAuthenticationSignature: finishData.activeAuthSignature
        )

        try await connection.send(message: message)
        try await stateMachine.transition(to: .finishing)
    }

    /// Close the session
    func closeSession(reason: String? = nil) async {
        if await stateMachine.canTransition(to: .closed) {
            try? await stateMachine.transition(to: .closed)
        }

        // Complete any waiting continuation with cancellation
        activeContinuation?.resume(throwing: CancellationError())
        activeContinuation = nil
    }

    // MARK: - Private Methods

    private func setupConnectionHandlers() {
        connection.onMessageReceived = { [weak self] result in
            Task { [weak self] in
                await self?.handleMessage(result)
            }
        }

        connection.onConnectionStateChanged = { [weak self] connected in
            Task { [weak self] in
                await self?.handleConnectionStateChange(connected)
            }
        }
    }

    private func handleMessage(_ result: Result<URLSessionWebSocketTask.Message, Error>) async {
        do {
            let message = try result.get()
            let parsed = try await messageHandler.parseMessage(message)

            // Validate message is expected
            if let messageType = parsed.messageType {
                try await stateMachine.validateMessageReceive(messageType)
            }

            // Handle based on message type
            switch parsed {
            case .accept(let msg):
                try await handleAcceptMessage(msg)

            case .caHandback(let msg):
                try await handleCAHandbackMessage(msg)

            case .result(let msg):
                try await handleResultMessage(msg)

            case .close(let msg):
                await handleCloseMessage(msg)

            case .binaryFile(let msg):
                handleBinaryFileMessage(msg)

            case .binaryAPDU(let msg):
                await handleBinaryAPDUMessage(msg)
            }

        } catch {
            // Treat "Socket is not connected" (57) as an immediate disconnect unless we've already completed/closed.
            let nsError = error as NSError
            if nsError.code == 57 {
                Logger.debug("Socket disconnected")
            }

            // Only log if it's not a normal disconnection after completion
            let currentState = await stateMachine.currentState
            if currentState != .completed && currentState != .closed {
                Logger.debug("Message handling error: \(error)")

                // Only notify about the error if it's not after successful completion (and not already notified)
                if !errorNotified {
                    errorNotified = true
                    onError?(error)
                }
            }

            // ALWAYS close NFC session and resume continuations on error,
            // even if state is already .closed (to avoid hanging operations)
            await closeNFCSession()

            // Resume any waiting continuations with error
            acceptContinuation?.resume(throwing: error)
            acceptContinuation = nil
            handbackContinuation?.resume(throwing: error)
            handbackContinuation = nil
            resultContinuation?.resume(throwing: error)
            resultContinuation = nil
            activeContinuation?.resume(throwing: error)
            activeContinuation = nil
            apduResponseContinuation?.resume(throwing: error)
            apduResponseContinuation = nil
        }
    }

    private func handleConnectionStateChange(_ connected: Bool) async {
        if connected {
            // Connection established, transition to connected if we're still in initial state
            let currentState = await stateMachine.currentState
            if currentState == .initial {
                do {
                    try await stateMachine.transition(to: .connected)
                } catch {
                    Logger.debug("Failed to transition to connected state: \(error)")
                }
            }
        } else {
            // Give CLOSE message time to be processed first
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay

            let isTerminal = await stateMachine.isTerminal
            let currentState = await stateMachine.currentState

            // Don't treat disconnection as error if we're already completed
            if currentState == .completed {
                Logger.debug("Connection closed after successful completion - ignoring")
                return
            }

            // But if state is .closed without completion, we still need to clean up
            if currentState == .closed {
                Logger.debug("Connection closed while already in closed state - cleaning up")
                // Still need to resume any hanging continuations
                acceptContinuation?.resume(throwing: EmrtdConnectorError.connectionClosed(reason: "Connection lost"))
                acceptContinuation = nil
                handbackContinuation?.resume(throwing: EmrtdConnectorError.connectionClosed(reason: "Connection lost"))
                handbackContinuation = nil
                resultContinuation?.resume(throwing: EmrtdConnectorError.connectionClosed(reason: "Connection lost"))
                resultContinuation = nil
                activeContinuation?.resume(throwing: EmrtdConnectorError.connectionClosed(reason: "Connection lost"))
                activeContinuation = nil
                return
            }

            // If we already have a specific error from CLOSE message, don't generate a generic one
            if self.closeError != nil {
                Logger.debug("Already have error from CLOSE message - skipping generic error")
                return
            }

            if !isTerminal {
                // Use the error from CLOSE message if available, otherwise create a generic one
                let error: EmrtdConnectorError

                if let closeError = self.closeError {
                    // We already have a specific error from the CLOSE message
                    error = closeError as? EmrtdConnectorError ?? .connectionClosed(reason: "Server closed connection")
                } else if currentState == .readingChip {
                    // If we're in the reading chip state, it's likely a timeout
                    error = .connectionTimeout
                } else {
                    error = .connectionClosed(reason: "Unexpected disconnection")
                }

                // Transition to failed state
                try? await stateMachine.transition(to: .failed)

                // Close NFC session if active
                await closeNFCSession()

                // Only notify about error if we haven't already done so
                if !errorNotified && self.closeError == nil && currentState != .completed && currentState != .closed {
                    errorNotified = true
                    onError?(error)
                }

                // Resume all waiting continuations with error (only if not already resumed by CLOSE)
                acceptContinuation?.resume(throwing: error)
                acceptContinuation = nil
                handbackContinuation?.resume(throwing: error)
                handbackContinuation = nil
                resultContinuation?.resume(throwing: error)
                resultContinuation = nil
                activeContinuation?.resume(throwing: error)
                activeContinuation = nil
                apduResponseContinuation?.resume(throwing: error)
                apduResponseContinuation = nil
            }
        }
    }

    // MARK: - Message Handlers

    private func handleAcceptMessage(_ message: AcceptMessage) async throws {
        // No sessionId in ACCEPT message according to v2 spec
        try await stateMachine.transition(to: .accepted)

        // Automatically transition to readingChip like Android does
        try await stateMachine.transition(to: .readingChip)

        // Store the accept message for later use
        messageBuffer.append(.accept(message))

        // Resume accept continuation if waiting
        acceptContinuation?.resume(returning: message)
        acceptContinuation = nil
    }

    private func handleCAHandbackMessage(_ message: CAHandbackMessage) async throws {
        Logger.debug("Received CA_HANDBACK: checkResult=\(message.checkResult), hasNewKeys=\(message.secureMessagingInfo != nil)")

        try await stateMachine.transition(to: .handbackReceived)

        // Store the handback message
        messageBuffer.append(.caHandback(message))

        // Resume handback continuation if waiting
        handbackContinuation?.resume(returning: message)
        handbackContinuation = nil
    }

    private func handleResultMessage(_ message: ResultMessage) async throws {
        try await stateMachine.transition(to: .completed)

        // Resume the result continuation with the validation result
        resultContinuation?.resume(returning: message.validationResult)
        resultContinuation = nil
    }

    private func handleCloseMessage(_ message: CloseMessage) async {
        Logger.debug("Received CLOSE message: reason=\(message.reason ?? "none"), code=\(message.code ?? 0)")

        // Check if this is a normal close (code 1000) after successful validation
        let previousState = await stateMachine.currentState
        let isNormalClose = message.code == 1000 || message.code == nil

        try? await stateMachine.transition(to: .closed)

        // Always notify about successful server post when we get close code 1000
        if isNormalClose {
            Logger.debug("Normal close (code 1000) - server post successful")
            onSuccessfulPost?()

            // If we already got the result, just return
            if previousState == .completed {
                Logger.debug("Already received result, closing normally")
                return
            }
            // If we are in fire-and-forget mode, treat normal close as success and return
            if !receiveResult {
                Logger.debug("Fire-and-forget mode - treating normal close as success")
                return
            }
        }

        // Create appropriate error based on close code and reason
        let error: EmrtdConnectorError

        // Try to parse the reason as a known CloseReason
        let closeReason = CloseReason.from(message.reason)

        if let code = message.code, let closeReason = closeReason {
            // We have a known close reason - use it
            error = .serverError(code: code, message: message.reason, reason: closeReason)
        } else if let code = message.code, code > 1000 {
            // Server error with code but unknown reason
            error = .serverError(code: code, message: message.reason, reason: nil)
        } else {
            // Generic connection closed
            error = .connectionClosed(reason: message.reason ?? "Server closed connection")
        }

        // Store the error for later use
        self.closeError = error

        // Notify about the error via callback (only once)
        if !errorNotified {
            errorNotified = true
            onError?(error)
        }

        // Resume all waiting continuations with error
        acceptContinuation?.resume(throwing: error)
        acceptContinuation = nil
        handbackContinuation?.resume(throwing: error)
        handbackContinuation = nil
        resultContinuation?.resume(throwing: error)
        resultContinuation = nil
        activeContinuation?.resume(throwing: error)
        activeContinuation = nil
        apduResponseContinuation?.resume(throwing: error)
        apduResponseContinuation = nil
    }

    private func handleBinaryFileMessage(_ message: BinaryFileMessage) {
        // For v2, files are sent as complete messages, no chunking
        Logger.debug("Received binary file: \(message.fileName), size: \(message.data.count) bytes")

        // Mark file as received to prevent duplicate sending
        receivedFiles.insert(message.fileName)

        // Store or process the file if needed
    }

    private func handleBinaryAPDUMessage(_ message: BinaryAPDUMessage) async {
        // This is an APDU command from the server that needs to be forwarded to the chip
        Logger.debug("Received APDU command from server: \(message.data.count) bytes")

        // Check if we're waiting for a command (client-initiated flow)
        if let continuation = apduResponseContinuation {
            // Client is waiting for this response
            continuation.resume(returning: message.data)
            apduResponseContinuation = nil
        } else {
            // Server-initiated APDU command - we need to forward it to the chip
            // This happens during CA when server sends commands
            await handleServerInitiatedAPDU(message.data)
        }
    }

    private func handleServerInitiatedAPDU(_ command: Data) async {
        // This is a server-initiated APDU during CA phase
        // Forward it to the chip using the integrated method

        do {
            // Forward the APDU command to the chip
            let response = try await forwardAPDUCommand(command)

            // Send the response back to the server
            let responseMessage = BinaryAPDUMessage(data: response)
            try await connection.send(data: responseMessage.encode())

        } catch {
            Logger.debug("Failed to forward server-initiated APDU: \(error)")

            // Send back an error response
            let errorResponse = Data([0x6F, 0x00]) // No precise diagnosis
            let responseMessage = BinaryAPDUMessage(data: errorResponse)

            do {
                try await connection.send(data: responseMessage.encode())
            } catch {
                Logger.debug("Failed to send APDU error response: \(error)")
            }
        }
    }

    // MARK: - Binary File Methods

    /// Send a binary file
    func sendBinaryFile(fileId: String, data: Data) async throws {
        // Check if file was already sent or received to prevent duplicates
        guard !sentFiles.contains(fileId) && !receivedFiles.contains(fileId) else {
            Logger.debug("Skipping duplicate file \(fileId) - already sent or received")
            return
        }

        let messages = await messageHandler.createFileMessages(
            fileId: fileId,
            data: data,
            chunkSize: 32768
        )

        for message in messages {
            try await connection.send(data: message.encode())
        }

        // Mark file as sent
        sentFiles.insert(fileId)

        Logger.debug("Sent binary file \(fileId): \(data.count) bytes")
    }

    private func getBufferedMessage<T>(_ type: T.Type) -> T? {
        for message in messageBuffer {
            switch message {
            case .accept(let msg as T):
                return msg
            case .caHandback(let msg as T):
                return msg
            case .result(let msg as T):
                return msg
            case .close(let msg as T):
                return msg
            default:
                continue
            }
        }
        return nil
    }

    // MARK: - Chip Session Helper Methods

    /// Validates that all required files were successfully read from the chip
    /// - Parameters:
    ///   - result: The EmrtdResult containing all read files
    ///   - requestedFiles: The files that were requested to be read
    /// - Throws: EmrtdConnectorError.incompleteRead if required files are missing
    private func validateRequiredFiles(
        result: EmrtdResult,
        requestedFiles: DataGroupSet
    ) throws {
        var missingFiles: [String] = []

        // Check mandatory files according to ICAO 9303 standard
        // DG1 (MRZ data) is mandatory
        if result.dg1File == nil {
            missingFiles.append("DG1")
        }

        // DG2 (facial image) is mandatory for all eMRTDs
        if result.dg2File == nil {
            missingFiles.append("DG2")
        }

        // Check specifically requested files
        // Only check files that were explicitly requested and are also mandatory
        if requestedFiles.contains(.dg1) && result.dg1File == nil && !missingFiles.contains("DG1") {
            missingFiles.append("DG1")
        }

        if requestedFiles.contains(.dg2) && result.dg2File == nil && !missingFiles.contains("DG2") {
            missingFiles.append("DG2")
        }

        // SOD is required for passive authentication
        if result.sodFile == nil {
            missingFiles.append("SOD")
        }

        // If any mandatory files are missing, throw an error
        if !missingFiles.isEmpty {
            Logger.debug("Validation failed - missing mandatory files: \(missingFiles.joined(separator: ", "))")
            throw EmrtdConnectorError.incompleteRead(
                missingFiles: missingFiles,
                reason: "Required files could not be read. This may be due to NFC interruption."
            )
        }

        Logger.debug("File validation passed - all mandatory files present")
    }

    private func createHandoverData(from state: HandoverState) -> HandoverData {
        // Convert files to base64 strings - but NOT DG14!
        // DG14 must be sent as binary BEFORE CA_HANDOVER
        var filesRead: [String: String] = [:]
        var binaryFilesToSend: [String: Data] = [:]

        let fileNames = state.filesRead.keys.map { $0.protocolName }
        Logger.debug("HandoverState contains files: \(fileNames.joined(separator: ", "))")

        for (fileName, value) in state.filesRead {
            // Files now come with ElementaryFileName from KinegramEmrtd
            Logger.debug("Processing file: \(fileName), size: \(value.count) bytes")

            if fileName == .DG14 {
                // DG14 must be sent as binary before CA_HANDOVER
                binaryFilesToSend[fileName.protocolName] = value
                Logger.debug("Added DG14 to pendingBinaryFiles")
            }
            // Do NOT send SOD before CA_HANDOVER - it's needed for Passive Authentication later
            // SOD will be sent after handback with other files
            // In v2 protocol, we don't send files in handover JSON
        }

        Logger.debug("pendingBinaryFiles contains \(binaryFilesToSend.count) files: \(binaryFilesToSend.keys.joined(separator: ", "))")

        // Store binary files to be sent before handover
        self.pendingBinaryFiles = binaryFilesToSend

        // Log CA handover data availability for debugging
        if let caData = state.caHandoverData {
            Logger.debug("CA handover data available: algorithm=\(caData.algorithm), keyIdRef=\(caData.keyIdRef?.hexEncodedString() ?? "nil")")
        } else if state.filesRead.keys.contains(.DG14) {
            Logger.debug("WARNING: DG14 present but no CA handover data available")
        }

        return HandoverData(
            secureMessagingInfo: state.secureMessagingInfo,
            filesRead: filesRead
        )
    }

    private func extractFilesFromResult(_ result: EmrtdResult) -> [String: Data] {
        var files: [String: Data] = [:]

        // Extract all available data groups from result
        // Use protocol names for wire protocol
        if let sod = result.sodFile { files[ElementaryFileName.SOD.protocolName] = Data(sod.data) }
        if let dg1 = result.dg1File { files[ElementaryFileName.DG1.protocolName] = Data(dg1.data) }
        if let dg2 = result.dg2File { files[ElementaryFileName.DG2.protocolName] = Data(dg2.data) }
        if let dg7 = result.dg7File { files[ElementaryFileName.DG7.protocolName] = Data(dg7.data) }
        if let dg11 = result.dg11File { files[ElementaryFileName.DG11.protocolName] = Data(dg11.data) }
        if let dg12 = result.dg12File { files[ElementaryFileName.DG12.protocolName] = Data(dg12.data) }
        if let dg14 = result.dg14File { files[ElementaryFileName.DG14.protocolName] = Data(dg14.data) }
        if let dg15 = result.dg15File { files[ElementaryFileName.DG15.protocolName] = Data(dg15.data) }

        return files
    }

    private func createFinishData(from files: [String: Data], result: EmrtdResult) -> FinishData {
        var filesRead: [String: String] = [:]
        var binaryFiles: [String: Data] = [:]

        for (key, value) in files {
            let fileId = key.lowercased()

            // Skip files already sent before CA_HANDOVER
            if pendingBinaryFiles.keys.contains(fileId) {
                Logger.debug("Skipping file \(fileId) - already sent before CA_HANDOVER")
                continue
            }

            // All files should be sent as binary in v2 protocol
            binaryFiles[fileId] = value
        }

        // Extract active auth signature if available
        var activeAuthSignature: String?
        if let signature = result.activeAuthenticationSignature {
            activeAuthSignature = signature.base64EncodedString()
            Logger.debug("Active Authentication signature captured: \(signature.count) bytes")
        }

        return FinishData(
            filesRead: filesRead, // Empty in v2, all files sent as binary
            binaryFiles: binaryFiles,
            activeAuthSignature: activeAuthSignature,
            readErrors: nil
        )
    }
}

// MARK: - Supporting Types

/// Result of a validation session
struct SessionResult {
    let validationResult: ValidationResult
    let sessionId: String
    let acceptMessage: AcceptMessage?
    let handbackMessage: CAHandbackMessage?
}

/// Data formatted for the WebSocket protocol CA_HANDOVER message
///
/// This struct contains only the data that needs to be sent to the server
/// in the CA_HANDOVER message according to the v2 protocol specification.
/// It's a subset of HandoverState, formatted for wire transmission.
///
/// - Note: HandoverState contains the complete session state from KinegramEmrtd,
///   while HandoverData contains only what the server needs for CA.
struct HandoverData {
    /// Secure messaging info (SSC, keys) for the server to continue the session
    let secureMessagingInfo: SecureMessagingInfo
    /// Files read so far (not used in v2, kept for compatibility)
    let filesRead: [String: String]  // Wire protocol uses string keys
}

/// Data for finishing the session
struct FinishData {
    let filesRead: [String: String]
    let binaryFiles: [String: Data]
    let activeAuthSignature: String?
    let readErrors: [String: String]?
}

/// Result of chip reading with handover
///
/// ## Why both HandoverState and HandoverData?
///
/// - **HandoverState**: The complete NFC session state from KinegramEmrtd.
///   Contains everything needed to resume the session after CA, including
///   the NFC tag reference, secure messaging state, files read, etc.
///   This is what we keep locally to continue reading after handback.
///
/// - **HandoverData**: The wire protocol representation for the server.
///   Contains only the secure messaging info that the server needs to
///   perform Chip Authentication. This is what we send in CA_HANDOVER.
///
/// Think of it like saving a game:
/// - HandoverState = Full save file (everything to resume playing)
/// - HandoverData = Cloud sync data (just what the server needs)
struct ChipReadingResult {
    /// Complete state to resume NFC session after CA
    let handoverState: HandoverState
    /// Wire protocol data to send to server
    let handoverData: HandoverData
}

/// Result of completing chip reading
struct CompleteReadingResult {
    let emrtdResult: [String: Data]
    let finishData: FinishData
}

// MARK: - Extensions

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Extension for CAHandbackInfo conversion

extension KinegramEmrtd.CAHandbackInfo {
    init(from protocolHandback: CAHandbackMessage) {
        // CAHandbackInfo uses CACheckResult enum
        let checkResult = KinegramEmrtd.CACheckResult(rawValue: protocolHandback.checkResult) ?? .unavailable

        self.init(
            checkResult: checkResult,
            secureMessagingInfo: protocolHandback.secureMessagingInfo,
            dg1Data: protocolHandback.dg1Data.flatMap { Data(base64Encoded: $0) }
        )
    }
}
