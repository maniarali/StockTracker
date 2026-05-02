//
//  StockEchoFeed.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public protocol StockEchoFeed: Sendable {
    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) async -> AsyncStream<WebSocketPublicEvent>

    func beginTransport() async
    func stopTransport() async
    func applyOutboundSuspension(_ suspended: Bool) async
}
