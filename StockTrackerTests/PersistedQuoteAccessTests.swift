//
//  PersistedQuoteAccessTests.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 04/05/2026.
//

import StockTrackerDomain
import SwiftData
import XCTest

@testable import StockTracker

@MainActor
final class PersistedQuoteAccessTests: XCTestCase {
    func testQuotesPageEmptyWhenLimitZero() throws {
        let schema = Schema([PersistedQuote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let page = try PersistedQuoteAccess.quotesPage(context: context, limit: 0, cursor: nil)
        XCTAssertTrue(page.quotes.isEmpty)
        XCTAssertNil(page.nextCursor)
    }
}
