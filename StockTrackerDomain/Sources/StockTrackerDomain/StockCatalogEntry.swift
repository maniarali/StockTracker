//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public struct StockCatalogEntry: Equatable, Hashable, Sendable, Identifiable {
    public var id: String { symbol }
    public let symbol: String
    public let companyName: String
    public let descriptionText: String

    public init(symbol: String, companyName: String, descriptionText: String) {
        self.symbol = symbol
        self.companyName = companyName
        self.descriptionText = descriptionText
    }
}
