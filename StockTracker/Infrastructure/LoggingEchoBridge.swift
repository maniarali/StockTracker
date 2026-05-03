//
//  LoggingEchoBridge.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation
import StockSocketKit
import StockTrackerDomain

struct LoggingEchoBridge: EchoLogger {
    private let logging: Logging

    init(logging: Logging) {
        self.logging = logging
    }

    nonisolated func debug(_ message: @autoclosure () -> String) {
        logging.log(.debug, message())
    }

    nonisolated func info(_ message: @autoclosure () -> String) {
        logging.log(.info, message())
    }

    nonisolated func error(_ message: @autoclosure () -> String) {
        logging.log(.error, message())
    }
}
