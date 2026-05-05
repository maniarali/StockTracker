//
//  EchoTransportInstrumentation.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public typealias EchoTLSAuthChallengeCompletion =
    (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

public typealias EchoTLSAuthChallengeHandler =
    (URLAuthenticationChallenge, @escaping EchoTLSAuthChallengeCompletion) -> Void

/// Customizes TLS authentication for the WebSocket `URLSession`.
///
/// `Sendable` is unchecked because `URLAuthenticationChallenge` handling runs on `URLSession`'s delegate queue
/// while session state lives on `EchoWebSocketSession`; callers must treat the handler as queue-confined.
public struct EchoTLSHooks: @unchecked Sendable {
    public var onAuthenticationChallenge: EchoTLSAuthChallengeHandler?

    public init(
        onAuthenticationChallenge: EchoTLSAuthChallengeHandler? = nil
    ) {
        self.onAuthenticationChallenge = onAuthenticationChallenge
    }
}

/// Optional instrumentation hooks placed on the websocket driver (handshake timing, backoff, teardown).
public struct EchoTransportMetrics: Sendable {
    public var onReconnectSleep: (@Sendable (_ attemptCounter: Int, _ delayNanos: UInt64) -> Void)?

    public var onHandshakeCompleted: (@Sendable (_ success: Bool) -> Void)?

    public var onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)?

    public init(
        onReconnectSleep: (@Sendable (Int, UInt64) -> Void)? = nil,
        onHandshakeCompleted: (@Sendable (Bool) -> Void)? = nil,
        onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)? = nil
    ) {
        self.onReconnectSleep = onReconnectSleep
        self.onHandshakeCompleted = onHandshakeCompleted
        self.onTerminalTransportFailure = onTerminalTransportFailure
    }
}
