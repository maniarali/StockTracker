//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public struct QuotesPage: Equatable, Sendable {
    public let quotes: [StockQuote]
    public let nextCursor: String?

    public init(quotes: [StockQuote], nextCursor: String?) {
        self.quotes = quotes
        self.nextCursor = nextCursor
    }
}
