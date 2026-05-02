//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public enum FeedConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case stopped
    case failed(reason: FeedFailure)
}

public enum FeedFailure: Equatable, Sendable {
    case transportUnavailable
    case decodingFailed
    case closedByServer
    case cancelled
    case persistenceFailed
}
