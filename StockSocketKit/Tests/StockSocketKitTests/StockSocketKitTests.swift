//
//  StockSocketKitTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import XCTest

@testable import StockSocketKit

final class StockSocketKitTests: XCTestCase {
    func testBackoffIncreasesWithinCap() {
        let policy = ExponentialBackoffPolicy(
            initialNanoseconds: 1_000_000,
            multiplier: 2,
            maxNanoseconds: 10_000_000,
            jitterRatio: 0
        )

        XCTAssertGreaterThanOrEqual(policy.delayNanoseconds(forAttempt: 1), policy.delayNanoseconds(forAttempt: 0))
        XCTAssertLessThanOrEqual(policy.delayNanoseconds(forAttempt: 50), 10_000_000)
    }

    func testEchoPayloadRoundTrip() throws {
        let payload = EchoStockPayload(symbol: "AAPL", price: 123.45, previousClose: 120.10, emittedAtEpoch: 1_700_000_000)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EchoStockPayload.self, from: data)

        XCTAssertEqual(decoded.symbol, payload.symbol)
        XCTAssertEqual(decoded.price, payload.price, accuracy: 0.0001)
        XCTAssertEqual(decoded.previousClose, payload.previousClose, accuracy: 0.0001)
        XCTAssertEqual(decoded.emittedAtEpoch, payload.emittedAtEpoch, accuracy: 0.0001)
    }

    func testFakeEchoFeedEmitsDecodedTick() async throws {
        let payload = EchoStockPayload(symbol: "AAA", price: 10, previousClose: 9.5, emittedAtEpoch: 1_700_000_000)
        let feed = FakeEchoFeed(payloads: [payload])
        let stream = await feed.eventsStream(bufferingPolicy: .unbounded)

        async let producer: Void = feed.beginTransport()

        var sawTick = false

        for await event in stream {
            if case let .decodedTick(received) = event {
                XCTAssertEqual(received.symbol, payload.symbol)
                XCTAssertEqual(received.price, payload.price, accuracy: 0.0001)
                sawTick = true
                break
            }
        }

        XCTAssertTrue(sawTick)

        await feed.stopTransport()
        await producer
    }
}
