//
//  DefaultStockRepository.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation
import StockSocketKit
import StockTrackerDomain
import SwiftData

@MainActor
final class DefaultStockRepository: StockRepositoryProtocol {
    private let modelContext: ModelContext
    private let catalogEntries: [StockCatalogEntry]
    private let logging: Logging
    private let echoFeedBuilder: ([String]) async -> any StockEchoFeed
    private let quoteFanOut = BroadcastFanOut<StockQuote>()
    private let connectionFanOut = BroadcastFanOut<FeedConnectionState>()

    private var latestQuotes: [String: StockQuote] = [:]
    private var activeSession: (any StockEchoFeed)?
    private var socketConsumerTask: Task<Void, Never>?
    private var userRequestedStreaming = false
    private var lastReconnectAttempt = 0

    private var pendingPersistQuotes: [String: StockQuote] = [:]
    private var persistFlushTask: Task<Void, Never>?

    private(set) var currentFeedConnectionState: FeedConnectionState = .idle

    init(
        modelContext: ModelContext,
        catalogEntries: [StockCatalogEntry],
        logging: Logging,
        echoFeedBuilder: @escaping ([String]) async -> any StockEchoFeed
    ) {
        self.modelContext = modelContext
        self.catalogEntries = catalogEntries.sorted { $0.symbol < $1.symbol }
        self.logging = logging
        self.echoFeedBuilder = echoFeedBuilder
        hydrateFromPersistence()
    }

    deinit {
        socketConsumerTask?.cancel()
        persistFlushTask?.cancel()
        connectionFanOut.finishAll()
        quoteFanOut.finishAll()
    }

    func catalog() async -> [StockCatalogEntry] {
        catalogEntries
    }

    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        try PersistedQuoteAccess.quotesPage(context: modelContext, limit: limit, cursor: cursor)
    }

    func hasPersistedQuotes() async throws -> Bool {
        try PersistedQuoteAccess.hasAnyQuotes(context: modelContext)
    }

    func connectionEvents() -> AsyncStream<FeedConnectionState> {
        connectionFanOut.makeStream()
    }

    func quoteEvents() -> AsyncStream<StockQuote> {
        quoteFanOut.makeStream()
    }

    func startFeed() async {
        userRequestedStreaming = true
        await mountSocketConsumerIfNeeded()
    }

    func ensureFeedTransportMountedIfNeeded() async {
        guard userRequestedStreaming else {
            return
        }
        
        guard socketConsumerTask == nil else {
            return
        }
        
        if case .connected = currentFeedConnectionState {
            return
        }
        
        if case .connecting = currentFeedConnectionState {
            return
        }
        
        await mountSocketConsumerIfNeeded()
    }

    private func mountSocketConsumerIfNeeded() async {
        guard socketConsumerTask == nil else {
            return
        }

        emitConnectionState(.connecting)

        let symbols = catalogEntries.map(\.symbol)

        let feed = await echoFeedBuilder(symbols)

        activeSession = feed

        let stream = await feed.eventsStream(bufferingPolicy: WebSocketPublicEventStreamDefaults.bufferingPolicy)

        socketConsumerTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            async let _: Void = feed.beginTransport()

            for await event in stream {
                self.handle(socketEvent: event)
                if self.userRequestedStreaming == false {
                    break
                }
            }
        }
    }

    func restartFeed() async {
        let flushed = await flushPersistBatchNow()
        guard flushed else {
            emitConnectionState(.failed(reason: .persistenceFailed))
            return
        }

        socketConsumerTask?.cancel()
        socketConsumerTask = nil

        let session = activeSession
        activeSession = nil

        if let session {
            await session.stopTransport()
        }

        userRequestedStreaming = true
        await mountSocketConsumerIfNeeded()
    }

    func stopFeed() async {
        _ = await flushPersistBatchNow()

        userRequestedStreaming = false
        socketConsumerTask?.cancel()
        socketConsumerTask = nil

        if let session = activeSession {
            await session.stopTransport()
        }

        activeSession = nil
        emitConnectionState(.stopped)
    }

    func applySceneActivity(_ activity: ApplicationSceneActivity) async {
        guard let activeSession else {
            return
        }

        await activeSession.applyOutboundSuspension(activity != .active)
    }

    var isUserStreamingRequested: Bool {
        userRequestedStreaming
    }

    func currentMergedQuotes() -> [StockQuote] {
        mergedQuotes()
    }

    private func hydrateFromPersistence() {
        do {
            latestQuotes = try PersistedQuoteAccess.quotesBySymbol(context: modelContext)
        } catch {
            logging.log(.error, "Hydration failed \(error.localizedDescription)")
            latestQuotes = [:]
        }
    }

    private func mergedQuotes() -> [StockQuote] {
        catalogEntries.compactMap { entry in
            latestQuotes[entry.symbol]
        }
    }

    private func handle(socketEvent: WebSocketPublicEvent) {
        switch socketEvent {
        case .connected:
            yieldConnected()

        case let .disconnected(userInitiated):
            yieldDisconnected(userInitiated: userInitiated)

        case let .reconnectScheduled(attempt):
            yieldReconnectScheduled(attempt: attempt)

        case let .decodedTick(payload):
            ingestDecodedTick(payload)

        case let .transportFailure(failure):
            yieldTransportFailure(failure)
        }
    }

    private func emitConnectionState(_ state: FeedConnectionState) {
        currentFeedConnectionState = state
        connectionFanOut.yield(state)
    }

    private func yieldConnected() {
        emitConnectionState(.connected)
    }

    private func yieldDisconnected(userInitiated: Bool) {
        if userInitiated {
            emitConnectionState(.stopped)
        } else {
            emitConnectionState(.reconnecting(attempt: lastReconnectAttempt))
        }
    }

    private func yieldReconnectScheduled(attempt: Int) {
        lastReconnectAttempt = attempt
        emitConnectionState(.reconnecting(attempt: attempt))
    }

    private func ingestDecodedTick(_ payload: EchoStockPayload) {
        guard let quote = DomainQuoteMapping.quote(from: payload) else {
            terminateFeedWithFailure(.decodingFailed)
            return
        }

        latestQuotes[quote.symbol] = quote
        quoteFanOut.yield(quote)
        schedulePersistFlush(quote)
    }

    private func schedulePersistFlush(_ quote: StockQuote) {
        pendingPersistQuotes[quote.symbol] = quote
        persistFlushTask?.cancel()
        persistFlushTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: QuoteStreamPresentationTiming.persistFlushDebounce)
            await flushPendingPersists()
        }
    }

    private func flushPendingPersists() async {
        let batch = Array(pendingPersistQuotes.values)
        pendingPersistQuotes.removeAll()
        persistFlushTask = nil
        guard batch.isEmpty == false else {
            return
        }

        do {
            try PersistedQuoteWriter.upsertBatch(quotes: batch, context: modelContext)
        } catch {
            logging.log(.error, "Persist failure \(error.localizedDescription)")
            terminateFeedWithFailure(.persistenceFailed)
        }
    }

    /// Flushes pending quote writes immediately (e.g. stop / restart). Returns whether disk write succeeded.
    @discardableResult
    private func flushPersistBatchNow() async -> Bool {
        persistFlushTask?.cancel()
        persistFlushTask = nil
        let batch = Array(pendingPersistQuotes.values)
        pendingPersistQuotes.removeAll()
        guard batch.isEmpty == false else {
            return true
        }

        do {
            try PersistedQuoteWriter.upsertBatch(quotes: batch, context: modelContext)
            return true
        } catch {
            logging.log(.error, "Persist failure \(error.localizedDescription)")
            return false
        }
    }

    private func yieldTransportFailure(_ failure: WebSocketTransportFailure) {
        switch failure {
        case .cancelled:
            terminateFeedWithFailure(.cancelled)

        case .decodingFailed:
            terminateFeedWithFailure(.decodingFailed)

        case .closedUnexpectedly:
            terminateFeedWithFailure(.transportUnavailable)

        case .handshakeFailed:
            terminateFeedWithFailure(.closedByServer)
        }
    }

    private func terminateFeedWithFailure(_ reason: FeedFailure) {
        persistFlushTask?.cancel()
        persistFlushTask = nil
        pendingPersistQuotes.removeAll()
        emitConnectionState(.failed(reason: reason))
        Task { @MainActor [weak self] in
            await self?.fullTeardownAfterTerminalFailure()
        }
    }

    private func fullTeardownAfterTerminalFailure() async {
        socketConsumerTask?.cancel()
        socketConsumerTask = nil

        let session = activeSession
        activeSession = nil
        await session?.stopTransport()
    }
}
