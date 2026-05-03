//
//  OSLogStockLogger.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation
import os
import StockTrackerDomain

struct OSLogStockLogger: Logging {
    private let logger = Logger(subsystem: "com.maniar.StockTracker", category: "app")

    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        let resolved = message()
        switch level {
        case .debug:
            logger.debug("\(resolved, privacy: .private)")
        case .info:
            logger.info("\(resolved, privacy: .private)")
        case .error:
            logger.error("\(resolved, privacy: .private)")
        }
    }
}
