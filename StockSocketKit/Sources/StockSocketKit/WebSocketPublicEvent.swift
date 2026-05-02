//
//  WebSocketPublicEvent.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public enum WebSocketPublicEvent: Equatable, Sendable {
    case connected
    case disconnected(userInitiated: Bool)
    case reconnectScheduled(attempt: Int)
    case decodedTick(EchoStockPayload)
    case transportFailure(WebSocketTransportFailure)
}

public enum WebSocketTransportFailure: Equatable, Sendable {
    case handshakeFailed
    case closedUnexpectedly
    case decodingFailed
    case cancelled
}
