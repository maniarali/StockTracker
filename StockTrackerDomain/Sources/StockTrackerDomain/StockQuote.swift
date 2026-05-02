//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public struct StockQuote: Equatable, Hashable, Sendable, Identifiable {
    public var id: String { symbol }
    public let symbol: String
    public let price: Decimal
    public let previousClose: Decimal
    public let updatedAt: Date

    public init(symbol: String, price: Decimal, previousClose: Decimal, updatedAt: Date) {
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.updatedAt = updatedAt
    }

    public var dayChange: Decimal {
        price - previousClose
    }

    public var dayChangePercent: Decimal {
        guard previousClose != 0 else {
            return 0
        }
        return (dayChange / previousClose) * 100
    }
}
