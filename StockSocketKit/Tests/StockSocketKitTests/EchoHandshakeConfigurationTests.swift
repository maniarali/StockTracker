//
//  EchoHandshakeConfigurationTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import XCTest
import Synchronization

@testable import StockSocketKit

private struct TransportMetricsCaptureState {
    var attempt = 0
    var nanos = UInt64(0)
}

private final class TransportMetricsReconnectGate: @unchecked Sendable {
    private let mutex = Mutex(TransportMetricsCaptureState())

    func capture(attempt: Int, nanos: UInt64) {
        mutex.withLock { state in
            state.attempt = attempt
            state.nanos = nanos
        }
    }

    func values() -> (attempt: Int, nanos: UInt64) {
        mutex.withLock { (attempt: $0.attempt, nanos: $0.nanos) }
    }
}

final class EchoHandshakeConfigurationTests: XCTestCase {
    func testHandshakeTimeoutIsInjectableForTestTuning() async throws {
        let nano = UInt64(777_777)
        let session = EchoWebSocketSession(
            url: URL(string: "wss://example.invalid")!,
            symbols: ["TST"],
            outboundIntervalNanoseconds: 900_000_000,
            backoffPolicy: ExponentialBackoffPolicy(
                initialNanoseconds: 1,
                multiplier: 1,
                maxNanoseconds: 1,
                jitterRatio: 0
            ),
            logger: nil,
            handshakeTimeoutNanoseconds: nano
        )

        let read = await session.handshakeTimeoutNanosecondsConfigured
        XCTAssertEqual(read, nano)
        await session.stop()
    }

    func testTransportMetricsReconnectCallbackReceivesBackoffPolicyValues() {
        let gate = TransportMetricsReconnectGate()
        let backoff = ExponentialBackoffPolicy(
            initialNanoseconds: 8_888,
            multiplier: 2,
            maxNanoseconds: 8_888,
            jitterRatio: 0
        )

        let metrics = EchoTransportMetrics(
            onReconnectSleep: { attempt, nanos in
                gate.capture(attempt: attempt, nanos: nanos)
            }
        )

        metrics.onReconnectSleep?(2, backoff.delayNanoseconds(forAttempt: 1))

        let captured = gate.values()
        XCTAssertEqual(captured.attempt, 2)
        XCTAssertEqual(captured.nanos, backoff.delayNanoseconds(forAttempt: 1))
    }
}
