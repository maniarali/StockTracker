//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import StockTrackerDomain
import XCTest

final class StockTrackerDomainTests: XCTestCase {
    func testSortOptionCasesAreStable() {
        XCTAssertEqual(SortOption.allCases.count, 4)
    }

    func testQuoteDerivedMovementMatchesExpectation() {
        let quote = StockQuote(symbol: "AAA", price: 110, previousClose: 100, updatedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(quote.dayChange, 10)
        XCTAssertEqual(NSDecimalNumber(decimal: quote.dayChangePercent).doubleValue, 10, accuracy: 0.0001)
    }

    func testPersistenceFailureCaseIsDistinct() {
        XCTAssertNotEqual(FeedFailure.persistenceFailed, .transportUnavailable)
    }
}
