//
//  QuoteStreamPresentationTiming.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

/// Debounce and coalescing intervals shared by the repository and presentation layer.
enum QuoteStreamPresentationTiming {
    /// Batches SwiftData writes while ticks are arriving quickly.
    nonisolated static let persistFlushDebounce: Duration = .milliseconds(280)

    /// Throttles SwiftUI refreshes during bursty quote updates (list and detail).
    nonisolated static let uiRefreshCoalesce: Duration = .milliseconds(120)
}
