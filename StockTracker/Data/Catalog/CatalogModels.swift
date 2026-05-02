//
//  CatalogModels.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

struct CatalogRecordDTO: Codable, Sendable {
    let symbol: String
    let companyName: String
    let descriptionText: String
}
