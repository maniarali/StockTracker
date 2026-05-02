//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public enum LogLevel: Sendable {
    case debug
    case info
    case error
}

public protocol Logging: Sendable {
    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String)
}
