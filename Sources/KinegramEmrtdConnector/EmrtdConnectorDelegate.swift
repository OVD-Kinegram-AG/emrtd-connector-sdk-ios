//
//  EmrtdConnectorDelegate.swift
//  kinegram_emrtd_connector
//
//  Created by Tim Vogel on 26.01.22.
//

/// The delegate of the ``EmrtdConnector``.
public protocol EmrtdConnectorDelegate: AnyObject {

    ///
    /// Wether to request the result from the DocVal Server.
    ///
    /// - Returns: `true` or `false` respectively
    ///
    func shouldRequestEmrtdPassport() -> Bool

    ///
    /// Tells the delegate that a new status is available.
    ///
    /// - Parameters:
    ///     - emrtdConnector: The EmrtdConnector instance.
    ///     - status:  The new status from the DocVal Server
    ///
    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didUpdateStatus status: EmrtdConnector.Status)

    ///
    /// Tells the delegate that the result is available.
    ///
    /// Will be called *after* the DocVal Server finished communicating with the eMRTD
    /// Will only be called if function `shouldRequestEmrtdPassport()` returns `true`.
    /// Will only be called if the session finishes successfully (and was not aborted).
    ///
    /// - Parameters:
    ///     - emrtdConnector: The EmrtdConnector instance.
    ///     - emrtdPassport: The result from the DocVal Server
    ///
    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didReceiveEmrtdPassport emrtdPassport: EmrtdPassport?)

    ///
    /// Tells the delegate that the WebSocket Session was closed.
    ///
    /// - Parameters:
    ///     - emrtdConnector: The EmrtdConnector instance.
    ///     - closeCode: The WebSocket Connection Close Code
    ///     - reason: The WebSocket Connection Close Reason
    ///
    func emrtdConnector(_ emrtdConnector: EmrtdConnector, didCloseWithCloseCode closeCode: Int, reason: EmrtdConnector.CloseReason?)
}

extension EmrtdConnectorDelegate {
    func emrtdConnector(_: EmrtdConnector, didUpdateStatus _: EmrtdConnector.Status) {}
    func emrtdConnector(_: EmrtdConnector, didReceiveEmrtdPassport _: EmrtdPassport?) {}
}
