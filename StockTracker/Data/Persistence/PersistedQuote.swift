//
//  PersistedQuote.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation
import SwiftData

@Model
final class PersistedQuote {
    @Attribute(.unique) var symbol: String
    var priceString: String
    var previousCloseString: String
    var updatedAt: Date

    init(symbol: String, priceString: String, previousCloseString: String, updatedAt: Date) {
        self.symbol = symbol
        self.priceString = priceString
        self.previousCloseString = previousCloseString
        self.updatedAt = updatedAt
    }
}
