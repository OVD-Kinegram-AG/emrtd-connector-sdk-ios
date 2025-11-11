import Foundation

/// Manages the WebSocket connection using URLSessionWebSocketTask
actor WebSocketConnection {
    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var isConnected = false
    private var pingTimer: Timer?
    private let httpHeaders: [String: String]

    /// Message receive handler
    nonisolated(unsafe) var onMessageReceived: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?

    /// Connection state change handler
    nonisolated(unsafe) var onConnectionStateChanged: ((Bool) -> Void)?

    init(url: URL, urlSession: URLSession = .shared, httpHeaders: [String: String] = [:]) {
        self.url = url
        self.session = urlSession
        self.httpHeaders = httpHeaders
    }

    deinit {
        pingTimer?.invalidate()
    }

    // MARK: - Connection Management

    /// Connect to the WebSocket server
    func connect() async throws {
        guard !isConnected else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        // Add required headers
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("permessage-deflate", forHTTPHeaderField: "Sec-WebSocket-Extensions")

        // Add custom HTTP headers
        for (key, value) in httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Wait for connection confirmation via ping/pong
        let connectionConfirmed = await waitForConnectionConfirmation()

        if connectionConfirmed {
            // Connection is truly established
            isConnected = true

            // Start receiving messages
            receiveMessage()

            // Start ping timer
            startPingTimer()

            Task { @MainActor in
                onConnectionStateChanged?(true)
            }

            Logger.debug("WebSocket connected to: \(url)")
        } else {
            // Connection failed - clean up
            webSocketTask?.cancel()
            webSocketTask = nil

            // Try to determine if it's a network issue
            let error = EmrtdConnectorError.noNetworkConnection
            Logger.debug("Connection failed - likely offline or server unreachable")
            throw error
        }
    }

    /// Disconnect from the WebSocket server
    func disconnect(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: String? = nil) async {
        guard isConnected else { return }

        pingTimer?.invalidate()
        pingTimer = nil

        isConnected = false

        // Give time for any pending messages to be received before closing
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let reasonData = reason?.data(using: .utf8)
        webSocketTask?.cancel(with: code, reason: reasonData)
        webSocketTask = nil

        Task { @MainActor in
            onConnectionStateChanged?(false)
        }

        Logger.debug("WebSocket disconnected with code: \(code), reason: \(reason ?? "none")")
    }

    /// Check if connected
    func checkConnection() -> Bool {
        return isConnected
    }

    // MARK: - Message Handling

    /// Send a text message
    func send(text: String) async throws {
        guard isConnected else {
            throw EmrtdConnectorError.notConnected
        }

        let message = URLSessionWebSocketTask.Message.string(text)
        try await webSocketTask?.send(message)

        Logger.debug("Sent text message: \(text.prefix(600))...")
    }

    /// Send a binary message
    func send(data: Data) async throws {
        guard isConnected else {
            throw EmrtdConnectorError.notConnected
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)

        Logger.debug("Sent binary message: \(data.count) bytes")
    }

    /// Send a WebSocket message
    func send(message: any WebSocketMessage) async throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        try await send(text: jsonString)
    }

    // MARK: - Private Methods

    /// Wait for connection confirmation via ping/pong
    /// Returns true if connection is confirmed, false if timeout or error
    private func waitForConnectionConfirmation() async -> Bool {
        guard let task = webSocketTask else { return false }

        // Race ping completion against a timeout without leaking continuations
        return await withCheckedContinuation { continuation in
            // Ensure we only resume once
            let lock = NSLock()
            var resumed = false
            func resumeOnce(_ value: Bool) {
                lock.lock(); defer { lock.unlock() }
                if resumed { return }
                resumed = true
                continuation.resume(returning: value)
            }

            // Schedule timeout (3 seconds)
            Task { [weak self] in
                // If the actor deinitializes, just resume false to be safe
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                resumeOnce(false)
            }

            // Send a ping to confirm connection
            task.sendPing { error in
                if let error = error {
                    Logger.debug("Connection confirmation ping failed: \(error)")
                    resumeOnce(false)
                } else {
                    // Ping succeeded - connection is confirmed
                    resumeOnce(true)
                }
            }
        }
    }

    /// Continuously receive messages
    private func receiveMessage() {
        // Ensure we have an active task
        guard let task = webSocketTask else { return }

        task.receive { [weak self] result in
            guard let self = self else { return }

            Task {
                await self.handleReceivedMessage(result)

                // IMPORTANT: Continue receiving even if we think we're done
                // iOS WebSocket requires continuous receive calls to get close frames
                if await self.hasActiveTask() {
                    await self.receiveMessage()
                } else {
                    Logger.debug("Stopping receive loop - disconnected or no task")
                }
            }
        }
    }

    /// Handle received message
    private func handleReceivedMessage(_ result: Result<URLSessionWebSocketTask.Message, Error>) async {
        switch result {
        case .success(let message):
            Task { @MainActor in
                onMessageReceived?(result)
            }

            switch message {
            case .string(let text):
                Logger.debug("Received text message: \(text.prefix(800))...")
                // Logger.debug("Received text message: \(text)")
            case .data(let data):
                Logger.debug("Received binary message: \(data.count) bytes")
            @unknown default:
                break
            }

        case .failure(let error):
            // Check if this is a connection error
            if (error as NSError).code == 57 { // regular disconnect - "Socket is not connected"
                // Don't log as error - this is expected after CLOSE message
                await handleDisconnection()
            } else {
                Logger.debug("Receive error: \(error)")
            }

            Task { @MainActor in
                onMessageReceived?(result)
            }
        }
    }

    /// Check whether we still have an active connection and task
    private func hasActiveTask() -> Bool {
        return isConnected && webSocketTask != nil
    }

    /// Handle unexpected disconnection
    private func handleDisconnection() async {
        guard isConnected else { return }

        isConnected = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask = nil

        Task { @MainActor in
            onConnectionStateChanged?(false)
        }

        // Only log if it's actually unexpected (not after successful close)
        if isConnected {
            Logger.debug("WebSocket disconnected unexpectedly")
        }
    }

    /// Start ping timer to keep connection alive
    private func startPingTimer() {
        pingTimer?.invalidate()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.sendPing()
            }
        }
    }

    /// Send ping to keep connection alive
    private func sendPing() async {
        guard isConnected else { return }

        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                Logger.debug("Ping failed: \(error)")
                Task { [weak self] in
                    await self?.handleDisconnection()
                }
            }
        }
    }
}

// MARK: - URLSession Configuration Extension

extension URLSession {
    /// Create a URLSession configured for WebSocket use
    static func webSocketSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        // Handshake/request operations can legitimately take longer in
        // adverse network conditions. Also, reading on-device can take
        // significant time with few WS exchanges – avoid spurious timeouts.
        configuration.timeoutIntervalForRequest = 60   // seconds
        configuration.timeoutIntervalForResource = 600 // seconds
        configuration.waitsForConnectivity = false  // Don't wait for connectivity - fail fast
        configuration.allowsCellularAccess = true

        return URLSession(configuration: configuration)
    }
}
