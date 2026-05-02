//
//  StockTrackerDomainTests.swift
//  StockTrackerDomain
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

public enum ApplicationSceneActivity: Sendable {
    case active
    case inactive
}

@MainActor
public protocol StockRepositoryProtocol: AnyObject {
    var currentFeedConnectionState: FeedConnectionState { get }
    var isUserStreamingRequested: Bool { get }

    func catalog() async -> [StockCatalogEntry]

    /// Paged persisted quotes ascending by symbol. `cursor` is the prior page's opaque `nextCursor` (empty same as nil).
    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage
    func hasPersistedQuotes() async throws -> Bool
    func connectionEvents() -> AsyncStream<FeedConnectionState>
    func quoteEvents() -> AsyncStream<StockQuote>
    func currentMergedQuotes() -> [StockQuote]

    func startFeed() async
    func stopFeed() async
    func restartFeed() async
    /// Mounts websocket transport while the consumer is idle, if streaming is requested. Safe to repeat.
    func ensureFeedTransportMountedIfNeeded() async

    func applySceneActivity(_ activity: ApplicationSceneActivity) async
}
