//
//  SortOption+Presentation.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import StockTrackerDomain

extension SortOption {
    var localizationKey: String {
        switch self {
        case .priceAscending:
            return "sort.price.asc"
        case .priceDescending:
            return "sort.price.desc"
        case .changeAscending:
            return "sort.change.asc"
        case .changeDescending:
            return "sort.change.desc"
        }
    }
}
