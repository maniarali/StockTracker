//
//  StocksScreenModel.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation
import Observation
import StockTrackerDomain

@Observable @MainActor
final class StocksScreenModel {
    private let repository: any StockRepositoryProtocol
    private let feedLifecycle: StockFeedLifecycleControlling
    private var connectionTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?
    private var quoteCoalesceTask: Task<Void, Never>?

    private(set) var rows: [StockRowUIModel] = []
    private(set) var connectionState: FeedConnectionState = .idle
    private(set) var failurePresentation: MessagePresentation?
    private(set) var hasCachedQuotes = false
    private(set) var isStreamingRequested = false

    private var catalog: [StockCatalogEntry] = []

    var sortOption: SortOption = .priceDescending {
        didSet {
            rebuildRows()
        }
    }

    init(repository: any StockRepositoryProtocol, feedLifecycle: StockFeedLifecycleControlling) {
        self.repository = repository
        self.feedLifecycle = feedLifecycle
    }

    var onboardingActive: Bool {
        hasCachedQuotes == false && repository.isUserStreamingRequested == false
    }

    func activate() async {
        catalog = await repository.catalog()

        await refreshCachedFlag()
        refreshStreamingFlag()
        connectionState = repository.currentFeedConnectionState
        rebuildRows()
        subscribeToRepositoryEvents()
    }

    func startStreaming() async {
        failurePresentation = nil
        await feedLifecycle.startUserStreaming()
        await refreshCachedFlag()
        refreshStreamingFlag()
        rebuildRows()
    }

    func stopStreaming() async {
        await feedLifecycle.stopUserStreaming()
        refreshStreamingFlag()
        rebuildRows()
    }

    func retryAfterFailure() async {
        failurePresentation = nil
        await feedLifecycle.restartUserFeedTransport()
        await refreshCachedFlag()
        refreshStreamingFlag()
        rebuildRows()
    }

    private func refreshCachedFlag() async {
        do {
            hasCachedQuotes = try await repository.hasPersistedQuotes()
        } catch {
            failurePresentation = .persistenceFailure
            hasCachedQuotes = false
        }
    }

    private func subscribeToRepositoryEvents() {
        connectionTask?.cancel()
        quoteTask?.cancel()
        quoteCoalesceTask?.cancel()
        connectionTask = nil
        quoteTask = nil
        quoteCoalesceTask = nil

        connectionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await state in repository.connectionEvents() {
                connectionState = state

                switch state {
                case let .failed(reason):
                    failurePresentation = MessagePresentationMapper.map(failure: reason)

                case .connected, .connecting, .reconnecting:
                    failurePresentation = nil

                case .idle, .stopped:
                    break
                }

                refreshStreamingFlag()
                rebuildRows()
            }
        }

        quoteTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await _ in repository.quoteEvents() {
                scheduleCoalescedQuoteRefresh()
            }
        }
    }

    private func scheduleCoalescedQuoteRefresh() {
        quoteCoalesceTask?.cancel()
        quoteCoalesceTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: QuoteStreamPresentationTiming.uiRefreshCoalesce)
            hasCachedQuotes = true
            refreshStreamingFlag()
            rebuildRows()
        }
    }

    private func refreshStreamingFlag() {
        isStreamingRequested = repository.isUserStreamingRequested
    }

    private func rebuildRows() {
        if onboardingActive {
            rows = []
            return
        }

        let stale = stalePresentationActive()
        let mergedQuotes = repository.currentMergedQuotes()
        let quotesBySymbol = Dictionary(uniqueKeysWithValues: mergedQuotes.map { ($0.symbol, $0) })

        let modelsBySymbol = Dictionary(uniqueKeysWithValues: catalog.map { entry in
            let model = StockUIMapper.rowUIModel(catalog: entry, quote: quotesBySymbol[entry.symbol], stalePresentation: stale)
            return (entry.symbol, model)
        })

        let sortedQuotes = mergedQuotes.sorted(by: sortOption)
        var orderedRows: [StockRowUIModel] = []

        for quote in sortedQuotes {
            if let model = modelsBySymbol[quote.symbol] {
                orderedRows.append(model)
            }
        }

        let includedSymbols = Set(orderedRows.map(\.symbol))
        let remainingSymbols = catalog.map(\.symbol).filter { includedSymbols.contains($0) == false }.sorted()

        for symbol in remainingSymbols {
            if let model = modelsBySymbol[symbol] {
                orderedRows.append(model)
            }
        }

        rows = orderedRows
    }

    private func stalePresentationActive() -> Bool {
        let connectedLive = repository.isUserStreamingRequested && connectionState == .connected
        return connectedLive == false
    }
}
