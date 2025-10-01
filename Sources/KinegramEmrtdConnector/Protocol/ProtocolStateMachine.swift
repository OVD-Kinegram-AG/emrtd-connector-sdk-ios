import Foundation

/// Represents the current state of the v2 protocol flow
enum ProtocolState: String {
    case initial
    case connecting
    case connected
    case started
    case accepted
    case readingChip
    case handoverSent
    case handbackReceived
    case finishing
    case completed
    case failed
    case closed
}

/// Manages the state transitions for the v2 protocol
actor ProtocolStateMachine {
    private(set) var currentState: ProtocolState = .initial
    private var stateHistory: [ProtocolState] = [.initial]

    /// Allowed state transitions
    private let allowedTransitions: [ProtocolState: Set<ProtocolState>] = [
        .initial: [.connected, .failed],
        .connecting: [.connected, .failed],
        .connected: [.started, .closed, .failed],
        .started: [.accepted, .closed, .failed],
        .accepted: [.readingChip, .closed, .failed],
        .readingChip: [.handoverSent, .finishing, .closed, .failed], // finishing for no-CA flow
        .handoverSent: [.handbackReceived, .closed, .failed],
        .handbackReceived: [.finishing, .closed, .failed],
        .finishing: [.completed, .closed, .failed],
        .completed: [.closed],
        .failed: [.closed],
        .closed: []
    ]

    /// Attempt to transition to a new state
    func transition(to newState: ProtocolState) throws {
        guard let allowedStates = allowedTransitions[currentState],
              allowedStates.contains(newState) else {
            throw EmrtdConnectorError.invalidState(
                current: currentState.rawValue,
                expected: newState.rawValue
            )
        }

        currentState = newState
        stateHistory.append(newState)

        Logger.debug("State transition: \(stateHistory[stateHistory.count - 2].rawValue) → \(newState.rawValue)")
    }

    /// Check if a transition is valid without performing it
    func canTransition(to state: ProtocolState) -> Bool {
        guard let allowedStates = allowedTransitions[currentState] else {
            return false
        }
        return allowedStates.contains(state)
    }

    /// Get the state history
    func getHistory() -> [ProtocolState] {
        return stateHistory
    }

    /// Reset the state machine
    func reset() {
        currentState = .initial
        stateHistory = [.initial]
    }

    /// Check if the state machine is in a terminal state
    var isTerminal: Bool {
        return currentState == .completed || currentState == .closed || currentState == .failed
    }

    /// Check if the state machine is in an active validation state
    var isActive: Bool {
        switch currentState {
        case .started, .accepted, .readingChip, .handoverSent, .handbackReceived, .finishing:
            return true
        default:
            return false
        }
    }
}

// MARK: - State Validation Extensions

extension ProtocolStateMachine {
    /// Validate that we can send a specific message type in the current state
    func validateMessageSend(_ messageType: MessageType) throws {
        let validStatesForMessage: [MessageType: Set<ProtocolState>] = [
            .start: [.connected],
            .caHandover: [.readingChip],
            .finish: [.handbackReceived, .readingChip], // readingChip for no-CA flow
            .close: [.connected, .started, .accepted, .readingChip, .handoverSent, .handbackReceived, .finishing, .completed, .failed]
        ]

        guard let validStates = validStatesForMessage[messageType],
              validStates.contains(currentState) else {
            throw EmrtdConnectorError.protocolError(
                message: "Cannot send \(messageType.rawValue) in state \(currentState.rawValue)"
            )
        }
    }

    /// Validate that we can receive a specific message type in the current state
    func validateMessageReceive(_ messageType: MessageType) throws {
        let validStatesForMessage: [MessageType: Set<ProtocolState>] = [
            .accept: [.started],
            .caHandback: [.handoverSent],
            .result: [.finishing],
            .close: Set(ProtocolState.allCases)
        ]

        guard let validStates = validStatesForMessage[messageType],
              validStates.contains(currentState) else {
            throw EmrtdConnectorError.unexpectedMessage(
                expected: expectedMessageType(),
                received: messageType.rawValue
            )
        }
    }

    /// Get the expected message type for the current state
    private func expectedMessageType() -> MessageType {
        switch currentState {
        case .started:
            return .accept
        case .handoverSent:
            return .caHandback
        case .finishing:
            return .result
        default:
            return .close
        }
    }
}

// MARK: - Timeout Management

extension ProtocolStateMachine {
    /// Get the timeout duration for the current state
    var stateTimeout: TimeInterval {
        switch currentState {
        case .connecting:
            return 30.0 // 30 seconds to connect
        case .started:
            return 10.0 // 10 seconds for server to accept
        case .readingChip:
            return 20.0 // 20 seconds NFC timeout
        case .handoverSent:
            return 30.0 // 30 seconds for server CA
        case .finishing:
            return 60.0 // 60 seconds for large file transfers
        default:
            return 120.0 // 2 minutes default
        }
    }

    /// Check if the current state should timeout
    func checkTimeout(enteredAt: Date) -> Bool {
        let elapsed = Date().timeIntervalSince(enteredAt)
        return elapsed > stateTimeout
    }
}

// MARK: - Helper Extensions

extension ProtocolState: CaseIterable {}

// Simple logger placeholder
enum Logger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        #endif
    }
}
