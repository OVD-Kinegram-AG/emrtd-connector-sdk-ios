import Foundation
import CoreNFC
import KinegramEmrtd

/// Status updates for NFC reading progress, designed to update NFCReaderSession alertMessage
public struct NFCProgressStatus {
    public let step: ReadingStep
    public let progress: Progress
    public let alertMessage: String

    /// Individual steps during validation process
    public enum ReadingStep {
        // Connection phase
        case connectingToServer
        case waitingForPassport
        case connecting

        // Authentication phase
        case performingAccessControl  // Generic - covers both BAC and PACE

        // Reading phase
        case readingSOD
        case readingDG14
        case performingCA
        case readingDG1
        case readingDG2(progress: Float) // DG2 is large, track progress
        case readingDG7
        case readingDG11
        case readingDG12
        case readingDG15
        case performingAA

        // Server validation phase
        case validatingWithServer
        case finishing
        case done

        // Error states
        case error(message: String)

        /// Description for the step (in English)
        public var description: String {
            switch self {
            case .connectingToServer:
                return "Connecting to server"
            case .waitingForPassport:
                return "Hold passport near phone"
            case .connecting:
                return "Hold still"
            case .performingAccessControl:
                return "Performing Access Control"
            case .readingSOD:
                return "Reading Security Data"
            case .readingDG14:
                return "Reading Security Keys"
            case .performingCA:
                return "Authenticating Chip"
            case .readingDG1:
                return "Reading Document Data"
            case .readingDG2:
                return "Reading Biometric Data"
            case .readingDG7:
                return "Reading Signature"
            case .readingDG11:
                return "Reading Additional Data"
            case .readingDG12:
                return "Reading Additional Info"
            case .readingDG15:
                return "Reading Authentication Keys"
            case .performingAA:
                return "Verifying Document"
            case .validatingWithServer:
                return "Validating with server"
            case .finishing:
                return "Completing"
            case .done:
                return "Done"
            case .error(let message):
                return message
            }
        }

        /// Progress index for visual progress bar (0-7 scale like ChipVerify)
        var progressIndex: Int {
            switch self {
            case .connectingToServer:
                return 0
            case .waitingForPassport:
                return 0
            case .connecting, .performingAccessControl:
                return 1
            case .readingSOD:
                return 2
            case .readingDG14, .performingCA:
                return 3
            case .readingDG1:
                return 4
            case .readingDG2(let progress):
                // Keep progress lower to prevent iOS from thinking we're "done"
                // This helps prevent auto-success on connection loss
                if progress < 0.5 {
                    return 4
                } else if progress < 0.95 {
                    return 5
                } else {
                    return 5  // Never go to 6 during DG2 reading
                }
            case .readingDG7, .readingDG11, .readingDG12, .readingDG15:
                return 5
            case .performingAA:
                return 6
            case .validatingWithServer:
                return 6
            case .finishing, .done:
                return 7
            case .error:
                return 0  // Errors don't show progress
            }
        }
    }

    /// Visual progress representation
    public struct Progress {
        let current: Int
        let total: Int

        /// Create progress bar string like "▮▮▮▯▯▯▯"
        var visualProgress: String {
            String(repeating: "▮", count: current)
                .padding(toLength: total, withPad: "▯", startingAt: 0)
        }
    }

    /// Create a progress status
    public init(step: ReadingStep) {
        self.step = step
        self.progress = Progress(current: step.progressIndex, total: 7)

        // Build alert message with description and progress bar
        let progressBar = progress.visualProgress
        self.alertMessage = "\(step.description)\n\(progressBar)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Create status for file reading with byte progress
    public static func fileProgress(
        fileName: ElementaryFileName,
        readBytes: Int,
        totalBytes: Int
    ) -> NFCProgressStatus {
        // Special handling for DG2 which is typically large
        if fileName == .DG2 && totalBytes > 0 {
            let progress = Float(readBytes) / Float(totalBytes)
            return NFCProgressStatus(step: .readingDG2(progress: progress))
        }

        // Map other files to their steps
        let step: ReadingStep
        switch fileName {
        case .SOD:
            step = .readingSOD
        case .DG1:
            step = .readingDG1
        case .DG7:
            step = .readingDG7
        case .DG11:
            step = .readingDG11
        case .DG12:
            step = .readingDG12
        case .DG14:
            step = .readingDG14
        case .DG15:
            step = .readingDG15
        default:
            // For other files, use current reading phase
            step = .readingDG1
        }

        return NFCProgressStatus(step: step)
    }

    /// Common statuses
    public static let connectingToServer = NFCProgressStatus(step: .connectingToServer)
    public static let waitingForPassport = NFCProgressStatus(step: .waitingForPassport)
    public static let connecting = NFCProgressStatus(step: .connecting)
    public static let validatingWithServer = NFCProgressStatus(step: .validatingWithServer)
    public static let done = NFCProgressStatus(step: .done)

    /// Create an error status
    public static func error(_ message: String) -> NFCProgressStatus {
        return NFCProgressStatus(step: .error(message: message))
    }
}

/// Extension to make it easy to update NFC session
public extension NFCReaderSession {
    func updateProgress(_ status: NFCProgressStatus) {
        self.alertMessage = status.alertMessage
    }
}
