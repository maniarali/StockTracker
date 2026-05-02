//
//  WebSocketHandshakeCoordinator.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation
import Synchronization

internal final class WebSocketHandshakeAwaiter: @unchecked Sendable {
    private struct LockedState {
        var result: Result<Void, Error>?
        var waiters: [CheckedContinuation<Result<Void, Error>, Never>] = []
    }

    private let mutex = Mutex(LockedState())

    func waitHandshakeResult() async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            let immediate = mutex.withLock { state -> Result<Void, Error>? in
                if let existing = state.result {
                    return existing
                }
                state.waiters.append(continuation)
                return nil
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
    }

    func completeSuccess() {
        finish(.success(()))
    }

    func completeFailure(_ error: Error) {
        finish(.failure(error))
    }

    private func finish(_ outcome: Result<Void, Error>) {
        let toResume = mutex.withLock { state -> [CheckedContinuation<Result<Void, Error>, Never>] in
            guard state.result == nil else {
                return []
            }
            state.result = outcome
            let copied = state.waiters
            state.waiters.removeAll()
            return copied
        }
        for waiter in toResume {
            waiter.resume(returning: outcome)
        }
    }
}

internal final class EchoWebSocketURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let handshake: WebSocketHandshakeAwaiter
    private weak var owner: EchoWebSocketSession?
    private let tlsHooks: EchoTLSHooks?
    private var reportedOpen = false

    init(handshake: WebSocketHandshakeAwaiter, owner: EchoWebSocketSession, tlsHooks: EchoTLSHooks?) {
        self.handshake = handshake
        self.owner = owner
        self.tlsHooks = tlsHooks
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let handler = tlsHooks?.onAuthenticationChallenge else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        handler(challenge, completionHandler)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        reportedOpen = true
        handshake.completeSuccess()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if reportedOpen == false {
            handshake.completeFailure(error ?? URLError(.cannotConnectToHost))
        } else {
            owner?.urlSessionTaskDidComplete(error: error)
        }
    }
}
