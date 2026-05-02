//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public enum SortOption: String, CaseIterable, Sendable {
    case priceAscending
    case priceDescending
    case changeAscending
    case changeDescending
}

extension Array where Element == StockQuote {
    public func sorted(by option: SortOption) -> [StockQuote] {
        switch option {
        case .priceAscending:
            return sorted { $0.price < $1.price }
        case .priceDescending:
            return sorted { $0.price > $1.price }
        case .changeAscending:
            return sorted { $0.dayChange < $1.dayChange }
        case .changeDescending:
            return sorted { $0.dayChange > $1.dayChange }
        }
    }
}
