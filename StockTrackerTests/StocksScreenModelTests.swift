//
//  StocksScreenModelTests.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 04/05/2026.
//

import StockTrackerDomain
import XCTest

@testable import StockTracker

@MainActor
final class MockFeedLifecycle: StockFeedLifecycleControlling {
    private let repository: MockStockRepository

    init(repository: MockStockRepository) {
        self.repository = repository
    }

    func startUserStreaming() async {
        await repository.startFeed()
    }

    func stopUserStreaming() async {
        await repository.stopFeed()
    }

    func restartUserFeedTransport() async {
        await repository.restartFeed()
    }

    func observeReachabilityForAutomaticFeedRecovery() async {}
}

@MainActor
final class MockStockRepository: StockRepositoryProtocol {
    private let connections = BroadcastFanOut<FeedConnectionState>()
    private let quotes = BroadcastFanOut<StockQuote>()

    var catalogEntries: [StockCatalogEntry] = []
    var hasPersistedQuotesValue: Result<Bool, Error> = .success(false)

    private(set) var currentFeedConnectionState: FeedConnectionState = .idle
    private(set) var isUserStreamingRequested = false

    var mergedQuotes: [StockQuote] = []

    func catalog() async -> [StockCatalogEntry] {
        catalogEntries
    }

    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        QuotesPage(quotes: [], nextCursor: nil)
    }

    func hasPersistedQuotes() async throws -> Bool {
        try hasPersistedQuotesValue.get()
    }

    func connectionEvents() -> AsyncStream<FeedConnectionState> {
        connections.makeStream()
    }

    func quoteEvents() -> AsyncStream<StockQuote> {
        quotes.makeStream()
    }

    func currentMergedQuotes() -> [StockQuote] {
        mergedQuotes
    }

    func startFeed() async {
        isUserStreamingRequested = true
    }

    func stopFeed() async {
        isUserStreamingRequested = false
    }

    func restartFeed() async {}

    func ensureFeedTransportMountedIfNeeded() async {}

    func applySceneActivity(_ activity: ApplicationSceneActivity) async {}

    func pushConnectionState(_ state: FeedConnectionState) {
        currentFeedConnectionState = state
        connections.yield(state)
    }

    func pushQuote(_ quote: StockQuote) {
        quotes.yield(quote)
    }
}

@MainActor
final class StocksScreenModelTests: XCTestCase {
    func testPersistenceFailureMapsToPersistenceMessage() async {
        let repository = MockStockRepository()
        let lifecycle = MockFeedLifecycle(repository: repository)
        repository.hasPersistedQuotesValue = .success(true)

        let model = StocksScreenModel(repository: repository, feedLifecycle: lifecycle)
        await model.activate()

        // Let the connection subscription task start `for await` before emitting test events.
        await Task.yield()
        await Task.yield()

        repository.pushConnectionState(.failed(reason: .persistenceFailed))

        let deadline = ContinuousClock.now + .seconds(2)
        while model.failurePresentation == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(model.failurePresentation, .persistenceFailure)
    }

    func testStreamingStartUpdatesRowsWhenCacheExists() async throws {
        let repository = MockStockRepository()
        let lifecycle = MockFeedLifecycle(repository: repository)

        repository.catalogEntries = [
            StockCatalogEntry(symbol: "ZZZ", companyName: "Zed", descriptionText: "D"),
        ]
        repository.hasPersistedQuotesValue = .success(true)
        repository.mergedQuotes = [
            StockQuote(symbol: "ZZZ", price: 10, previousClose: 9, updatedAt: Date(timeIntervalSince1970: 1)),
        ]

        let model = StocksScreenModel(repository: repository, feedLifecycle: lifecycle)
        await model.activate()
        XCTAssertFalse(model.rows.isEmpty)

        await model.startStreaming()
        repository.pushConnectionState(.connected)

        try await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(model.isStreamingRequested)
    }
}
