import Foundation
import KinegramEmrtd

/// Main entry point for the eMRTD Connector v2 SDK
public class EmrtdConnector {
    private let serverURL: URL
    private let validationId: String
    private let clientId: String
    private let httpHeaders: [String: String]
    private let enableDiagnostics: Bool
    private let receiveResult: Bool

    private var connection: WebSocketConnection?
    private var sessionCoordinator: WebSocketSessionCoordinator?
    private let retryHandler = RetryHandler()

    /// Delegate for validation events
    public weak var delegate: EmrtdConnectorDelegate?

    /// Delegate for monitoring events from the eMRTD SDK
    public weak var monitoringDelegate: EmrtdConnectorMonitoringDelegate?

    /// Optional custom localization for NFC status messages
    /// If not provided, English default messages will be used
    public var nfcStatusLocalization: ((NFCProgressStatus) -> String)?

    /// Current connection state
    public private(set) var isConnected = false

    /// Initialize the connector
    /// - Parameters:
    ///   - serverURL: WebSocket server URL (wss://...)
    ///   - validationId: Unique validation identifier
    ///   - clientId: Client identifier
    ///   - httpHeaders: Optional custom HTTP headers for the WebSocket connection
    ///   - enableDiagnostics: Optional flag for enabling sending diagnostics data (used for debugging purposes)
    ///   - receiveResult: Whether to receive the validation result from the server (default: true)
    public init(serverURL: URL, validationId: String, clientId: String, httpHeaders: [String: String] = [:], enableDiagnostics: Bool = false, receiveResult: Bool = true) {
        self.serverURL = serverURL
        self.validationId = validationId
        self.clientId = clientId
        self.httpHeaders = httpHeaders
        self.enableDiagnostics = enableDiagnostics
        self.receiveResult = receiveResult
    }

    // MARK: - Public Methods

    /// Validates a document in one simple call
    ///
    /// This method handles the entire validation flow:
    /// 1. Connects to the server
    /// 2. Performs the validation
    /// 3. Disconnects from the server
    /// 4. Returns the result
    ///
    /// - Parameters:
    ///   - accessKey: MRZ or CAN key for chip access
    ///   - usePACEPolling: Whether to use PACE polling for PACE-enabled documents (requires iOS 16+)
    /// - Returns: Validation result
    /// - Throws: Various errors if validation fails
    public func validate(with accessKey: AccessKey, usePACEPolling: Bool = false) async throws -> ValidationResult {
        // Connect if needed
        if !isConnected {
            try await connect()
        }

        do {
            // Perform validation
            let result = try await startValidation(accessKey: accessKey, usePACEPolling: usePACEPolling)

            // Always disconnect after validation
            await disconnect()

            return result
        } catch {
            // Ensure disconnection on error
            await disconnect()
            throw error
        }
    }

    /// Connect to the WebSocket server
    /// 
    /// Note: You don't need to call this directly if using the `validate` methods.
    /// This is exposed for advanced use cases where you want to pre-connect.
    public func connect() async throws {
        guard !isConnected else { return }

        let urlSession = URLSession.webSocketSession()
        connection = WebSocketConnection(url: serverURL, urlSession: urlSession, httpHeaders: httpHeaders)

        try await connection?.connect()
        isConnected = true

        sessionCoordinator = WebSocketSessionCoordinator(
            connection: connection!,
            validationId: validationId,
            clientId: clientId,
            enableDiagnostics: enableDiagnostics,
            receiveResult: receiveResult,
            nfcStatusCallback: { [weak self] status in
                guard let self = self else { return }
                Task {
                    await self.delegate?.connector(self, didUpdateNFCStatus: status)
                }
            },
            nfcStatusLocalization: nfcStatusLocalization,
            errorCallback: { [weak self] error in
                guard let self = self else { return }
                Task {
                    // Only disconnect if we're still connected
                    if self.isConnected {
                        await self.disconnect()
                    }
                    await self.delegate?.connector(self, didFailWithError: error)
                }
            },
            successfulPostCallback: { [weak self] in
                guard let self = self else { return }
                Task {
                    await self.delegate?.connectorDidSuccessfullyPostToServer(self)
                }
            },
            monitoringDelegate: self
        )

        await delegate?.connectorDidConnect(self)
    }

    /// Connect to the WebSocket server with automatic retry
    public func connectWithRetry() async throws {
        guard !isConnected else { return }

        try await retryHandler.execute(
            operation: { [weak self] in
                guard let self = self else { throw EmrtdConnectorError.sessionExpired }
                try await self.connect()
            },
            isRetryable: { error in
                return error.isRetryable
            },
            onRetry: { [weak self] _, _ in
                guard let self = self else { return }
                // Connection retry is handled internally
            }
        )
    }

    /// Disconnect from the WebSocket server
    public func disconnect() async {
        guard isConnected else { return }

        // Mark as disconnected immediately to prevent double disconnection
        isConnected = false

        // First close the session (sends CLOSE message if needed)
        await sessionCoordinator?.closeSession()

        // Wait a bit to ensure any pending messages are processed
        // This addresses iOS WebSocket close handling issues
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then disconnect the WebSocket
        await connection?.disconnect()

        // Close any active NFC session and clear reader reference
        await sessionCoordinator?.closeNFCSession()

        connection = nil
        sessionCoordinator = nil

        await delegate?.connectorDidDisconnect(self)
    }

    /// Start validation with an access key
    /// - Parameters:
    ///   - accessKey: MRZ or CAN key for chip access
    ///   - usePACEPolling: Whether to use PACE polling for PACE-enabled documents (requires iOS 16+)
    /// - Returns: Validation result
    @discardableResult
    public func startValidation(accessKey: AccessKey, usePACEPolling: Bool = false) async throws -> ValidationResult {
        return try await startValidation(accessKey: accessKey, filesToRead: .standard, usePACEPolling: usePACEPolling)
    }

    /// Start validation with custom file selection
    /// - Parameters:
    ///   - accessKey: MRZ or CAN key for chip access
    ///   - filesToRead: Set of data groups to read
    ///   - usePACEPolling: Whether to use PACE polling for PACE-enabled documents (requires iOS 16+)
    /// - Returns: Validation result
    public func startValidation(
        accessKey: AccessKey,
        filesToRead: DataGroupSet,
        usePACEPolling: Bool = false
    ) async throws -> ValidationResult {
        // Check NFC availability first
        guard NFCCapabilityChecker.isAvailable else {
            let reason = NFCCapabilityChecker.unavailabilityReason ?? "NFC not available"
            throw EmrtdConnectorError.nfcNotAvailable(reason: reason)
        }

        guard isConnected else {
            throw EmrtdConnectorError.notConnected
        }

        guard let coordinator = sessionCoordinator else {
            throw EmrtdConnectorError.invalidState(
                current: "not initialized",
                expected: "initialized"
            )
        }

        await delegate?.connectorDidStartValidation(self)
        // Progress is reported via NFC status updates

        do {
            // Send START and wait for ACCEPT
            let acceptMessage = try await coordinator.sendStartAndWaitForAccept()
            // Progress is reported via NFC status updates in WebSocketSessionCoordinator

            // Convert base64 challenge to Data
            let activeAuthChallenge = Data(base64Encoded: acceptMessage.activeAuthenticationChallenge)

            // Perform chip reading with handover
            await delegate?.connectorWillReadChip(self)
            await delegate?.connector(self, didUpdateNFCStatus: .connecting)

            let chipResult = try await coordinator.performChipReading(
                accessKey: accessKey,
                activeAuthChallenge: activeAuthChallenge,
                usePACEPolling: usePACEPolling
            )

            // Check if we have DG14 for Chip Authentication
            let pendingFiles = await coordinator.getPendingBinaryFiles()
            let hasDG14 = pendingFiles.keys.contains("dg14")
            Logger.debug("Got \(pendingFiles.count) pending files to send before CA_HANDOVER. Has DG14: \(hasDG14)")

            let completeResult: CompleteReadingResult

            if hasDG14 {
                // CA flow: Send DG14, perform handover/handback
                //
                // ## What is Chip Authentication (CA)?
                //
                // CA verifies that the passport chip is genuine and not cloned.
                // It works by:
                // 1. Reading the chip's public key from DG14
                // 2. Server challenges the chip to prove it has the private key
                // 3. Establishes new, stronger encryption keys for secure messaging
                //
                // DG14 must be sent BEFORE CA_HANDOVER because the server needs
                // the public key to perform the authentication protocol.
                Logger.debug("DG14 present - performing Chip Authentication flow")

                // Send binary files BEFORE handover (especially DG14!)
                for (fileId, fileData) in pendingFiles {
                    Logger.debug("Sending binary file \(fileId): \(fileData.count) bytes")
                    try await coordinator.sendBinaryFile(fileId: fileId, data: fileData)
                    Logger.debug("Successfully sent binary file \(fileId) before CA_HANDOVER")
                }

                // Now send handover to server with HandoverState
                await delegate?.connectorDidPerformHandover(self)
                // Progress is reported via NFC status updates

                try await coordinator.sendHandover(chipResult.handoverData, handoverState: chipResult.handoverState)

                // Wait for handback message
                // Progress is reported via NFC status updates
                let handbackMessage = try await coordinator.waitForHandback()

                // Convert handback message to handback info
                let handbackInfo = KinegramEmrtd.CAHandbackInfo(from: handbackMessage)

                // DO NOT close the NFC session here - it must remain open for continueAfterHandback!
                // The session will be closed after all reading is complete

                // Complete chip reading with custom file selection
                await delegate?.connectorWillCompleteReading(self)

                completeResult = try await coordinator.completeChipReading(
                    handoverState: chipResult.handoverState,
                    handbackInfo: handbackInfo,
                    filesToRead: filesToRead,
                    usePACEPolling: usePACEPolling
                )
            } else {
                // No CA flow: Skip handover/handback, continue reading directly
                Logger.debug("No DG14 present - skipping Chip Authentication flow")

                await delegate?.connectorWillCompleteReading(self)

                // Complete reading without CA
                completeResult = try await coordinator.completeChipReadingWithoutCA(
                    handoverState: chipResult.handoverState,
                    filesToRead: filesToRead,
                    usePACEPolling: usePACEPolling
                )
            }

            // Send finish data
            // Progress is reported via NFC status updates
            try await coordinator.sendFinish(completeResult.finishData)

            // Wait for RESULT message from server (if receiveResult=true, server will send it)
            await delegate?.connector(self, didUpdateNFCStatus: .validatingWithServer)
            let validationResult = try await coordinator.waitForResult()

            // Done status is already sent by coordinator after file validation
            await delegate?.connectorDidCompleteValidation(self, result: validationResult)

            // Wait for server to send CLOSE message before cleaning up
            // This addresses iOS WebSocket issue where close messages can be missed
            await coordinator.waitForClose(timeout: 2.0)

            // Session is already closed by coordinator after showing Done status

            return validationResult

        } catch {
            // Close NFC session and clear reader reference on error
            await coordinator.closeNFCSession()

            // Don't report cancellation errors to delegate
            if !(error is CancellationError) {
                await delegate?.connector(self, didFailWithError: error)
            }
            throw error
        }
    }
}

// MARK: - MonitoringDelegate Implementation

extension EmrtdConnector: MonitoringDelegate {
    public func onNewMonitoringEvent(message: String) {
        // Forward to our monitoring delegate
        Task { [weak self] in
            guard let self = self else { return }
            await self.monitoringDelegate?.connector(self, didReceiveMonitoringMessage: message)

            // Also send to server if connected and diagnostics enabled
            if self.isConnected, self.enableDiagnostics {
                await self.sessionCoordinator?.sendMonitoringMessage(message)
            }
        }
    }
}

// MARK: - Delegate Protocols

/// Delegate protocol for validation events
public protocol EmrtdConnectorDelegate: AnyObject {
    /// Called when the connector successfully connects to the server
    func connectorDidConnect(_ connector: EmrtdConnector) async

    /// Called when the connector disconnects from the server
    func connectorDidDisconnect(_ connector: EmrtdConnector) async

    /// Called when validation starts
    func connectorDidStartValidation(_ connector: EmrtdConnector) async

    /// Called before reading the chip
    func connectorWillReadChip(_ connector: EmrtdConnector) async

    /// Called after performing CA handover
    func connectorDidPerformHandover(_ connector: EmrtdConnector) async

    /// Called before completing the reading process
    func connectorWillCompleteReading(_ connector: EmrtdConnector) async

    /// Called when validation completes successfully
    func connectorDidCompleteValidation(_ connector: EmrtdConnector, result: ValidationResult) async

    /// Called when the server successfully posts results to the result server (Close Code 1000)
    /// This is especially relevant when receiveResult is false
    func connectorDidSuccessfullyPostToServer(_ connector: EmrtdConnector) async

    /// Called when an error occurs
    func connector(_ connector: EmrtdConnector, didFailWithError error: Error) async

    /// Called when NFC reading status is updated (for updating NFCReaderSession alertMessage)
    func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async
}

/// Delegate protocol for monitoring events
public protocol EmrtdConnectorMonitoringDelegate: AnyObject {
    /// Called when a monitoring event occurs from the eMRTD SDK
    /// - Parameters:
    ///   - connector: The connector instance
    ///   - message: The monitoring message from the SDK
    func connector(_ connector: EmrtdConnector, didReceiveMonitoringMessage message: String) async
}

// MARK: - Default Delegate Implementation

public extension EmrtdConnectorDelegate {
    func connectorDidConnect(_ connector: EmrtdConnector) async {}
    func connectorDidDisconnect(_ connector: EmrtdConnector) async {}
    func connectorDidStartValidation(_ connector: EmrtdConnector) async {}
    func connectorWillReadChip(_ connector: EmrtdConnector) async {}
    func connectorDidPerformHandover(_ connector: EmrtdConnector) async {}
    func connectorWillCompleteReading(_ connector: EmrtdConnector) async {}
    func connectorDidCompleteValidation(_ connector: EmrtdConnector, result: ValidationResult) async {}
    func connectorDidSuccessfullyPostToServer(_ connector: EmrtdConnector) async {}
    func connector(_ connector: EmrtdConnector, didFailWithError error: Error) async {}
    func connector(_ connector: EmrtdConnector, didUpdateNFCStatus status: NFCProgressStatus) async {}
}

// MARK: - Convenience Result Extension

public extension ValidationResult {
    /// Check if validation was successful
    var isValid: Bool {
        return status == "VALID"
    }

    /// Get a human-readable summary
    var summary: String {
        var parts: [String] = ["Status: \(status)"]

        if let ca = chipAuthResult {
            parts.append("CA: \(ca)")
        }
        if let pa = passiveAuthResult {
            parts.append("PA: \(pa)")
        }
        if let aa = activeAuthResult {
            parts.append("AA: \(aa)")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Re-export KinegramEmrtd types

// Re-export all the types that users need from KinegramEmrtd
// This allows users to only import EmrtdConnector

// Access Keys
public typealias AccessKey = KinegramEmrtd.AccessKey
public typealias MRZKey = KinegramEmrtd.MRZKey
public typealias CANKey = KinegramEmrtd.CANKey

// Errors
public typealias EmrtdReaderError = KinegramEmrtd.EmrtdReaderError

// Results (if needed by users)
public typealias EmrtdResult = KinegramEmrtd.EmrtdResult
