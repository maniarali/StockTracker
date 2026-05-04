//
//  StockTrackerTests.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 04/05/2026.
//

import StockSocketKit
import StockTrackerDomain
import XCTest

@testable import StockTracker

final class MessagePresentationMapperTests: XCTestCase {
    func testPersistenceFailedUsesPersistenceCopy() {
        let mapped = MessagePresentationMapper.map(failure: .persistenceFailed)
        XCTAssertEqual(mapped.titleKey, MessagePresentation.persistenceFailure.titleKey)
        XCTAssertEqual(mapped.showsRetry, true)
    }
}

final class StockTrackerTests: XCTestCase {
    func testSortQuotesByPriceDescending() {
        let first = StockQuote(symbol: "AAA", price: 10, previousClose: 9, updatedAt: Date(timeIntervalSince1970: 1))
        let second = StockQuote(symbol: "BBB", price: 25, previousClose: 20, updatedAt: Date(timeIntervalSince1970: 2))

        let sorted = [first, second].sorted(by: .priceDescending)

        XCTAssertEqual(sorted.first?.symbol, "BBB")
        XCTAssertEqual(sorted.last?.symbol, "AAA")
    }

    func testSortQuotesByChangeAscending() {
        let lower = StockQuote(symbol: "AAA", price: 10, previousClose: 12, updatedAt: Date(timeIntervalSince1970: 1))
        let higher = StockQuote(symbol: "BBB", price: 12, previousClose: 10, updatedAt: Date(timeIntervalSince1970: 2))

        let sorted = [higher, lower].sorted(by: .changeAscending)

        XCTAssertEqual(sorted.first?.symbol, "AAA")
        XCTAssertEqual(sorted.last?.symbol, "BBB")
    }
}

final class DomainQuoteMappingTests: XCTestCase {
    func testMappingRejectsEmptySymbol() {
        let payload = EchoStockPayload(symbol: "", price: 1, previousClose: 1, emittedAtEpoch: 0)
        XCTAssertNil(DomainQuoteMapping.quote(from: payload))
    }

    func testMappingUppercasesSymbol() {
        let payload = EchoStockPayload(symbol: "xyz", price: 10.5, previousClose: 10, emittedAtEpoch: 1_700_000_000)
        let quote = DomainQuoteMapping.quote(from: payload)
        XCTAssertEqual(quote?.symbol, "XYZ")
    }
}
