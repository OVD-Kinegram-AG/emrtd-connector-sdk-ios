import Foundation

/// Simple retry handler with fixed delays
public actor RetryHandler {
    private let maxAttempts: Int
    private let retryDelay: TimeInterval

    public init(maxAttempts: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.maxAttempts = maxAttempts
        self.retryDelay = retryDelay
    }

    /// Execute an operation with retry logic
    public func execute<T>(
        operation: () async throws -> T,
        isRetryable: (Error) -> Bool = { _ in true },
        onRetry: ((Int, Error) async -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                guard isRetryable(error) && attempt < maxAttempts - 1 else {
                    throw error
                }

                // Notify about retry
                await onRetry?(attempt + 1, error)

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }

        throw lastError ?? RetryError.maxAttemptsReached
    }
}

/// Errors specific to retry operations
public enum RetryError: LocalizedError {
    case maxAttemptsReached

    public var errorDescription: String? {
        switch self {
        case .maxAttemptsReached:
            return "Maximum retry attempts reached"
        }
    }
}

/// Extension to determine if errors are retryable
public extension Error {
    var isRetryable: Bool {
        // EmrtdConnectorError
        if let connectorError = self as? EmrtdConnectorError {
            switch connectorError {
            case .connectionFailed, .connectionClosed, .connectionTimeout,
                 .webSocketError, .messageSendFailed:
                return true
            case .nfcTimeout, .nfcSessionFailed:
                return true
            case .serverError(let code, _, _):
                // Retry on 5xx server errors
                return code >= 500 && code < 600
            default:
                return false
            }
        }

        // URLError
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        // NFC errors - some are retryable
        let description = self.localizedDescription.lowercased()
        if description.contains("tag connection lost") ||
           description.contains("timeout") {
            return true
        }

        return false
    }
}
