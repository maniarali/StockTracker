//
//  StockPaletteEnvironment.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import SwiftUI

private enum StockPaletteKey: EnvironmentKey {
    static let defaultValue = StockPalette.palette(for: .light)
}

extension EnvironmentValues {
    var stockPalette: StockPalette {
        get { self[StockPaletteKey.self] }
        set { self[StockPaletteKey.self] = newValue }
    }
}
