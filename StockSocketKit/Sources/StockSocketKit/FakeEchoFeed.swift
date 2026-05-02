//
//  FakeEchoFeed.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public actor FakeEchoFeed {
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private var emitTask: Task<Void, Never>?
    private let payloads: [EchoStockPayload]
    private let onFinishedEmitting: (@Sendable () -> Void)?

    public init(payloads: [EchoStockPayload], onFinishedEmitting: (@Sendable () -> Void)? = nil) {
        self.payloads = payloads
        self.onFinishedEmitting = onFinishedEmitting
    }

    private func handleTermination() async {
        emitTask?.cancel()
        emitTask = nil
        continuation?.finish()
        continuation = nil
    }

    private func emitPayloads(_ payloads: [EchoStockPayload]) async {
        continuation?.yield(.connected)

        for payload in payloads {
            continuation?.yield(.decodedTick(payload))
        }

        onFinishedEmitting?()
    }
}

extension FakeEchoFeed: StockEchoFeed {
    public func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) async -> AsyncStream<WebSocketPublicEvent> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.handleTermination() }
            }
        }
    }

    public func beginTransport() async {
        emitTask?.cancel()

        let payloadsCopy = payloads

        emitTask = Task {
            await self.emitPayloads(payloadsCopy)
        }
    }

    public func stopTransport() async {
        emitTask?.cancel()
        emitTask = nil
        continuation?.yield(.disconnected(userInitiated: true))
        continuation?.finish()
        continuation = nil
    }

    public func applyOutboundSuspension(_ suspended: Bool) async {
        _ = suspended
    }
}
