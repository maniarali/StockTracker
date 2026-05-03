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
final class StockDetailViewModel {
    private let repository: any StockRepositoryProtocol
    private let symbol: String

    private var connectionTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?
    private var quoteCoalesceTask: Task<Void, Never>?

    private(set) var uiModel: StockDetailUIModel?
    private var catalogEntry: StockCatalogEntry?
    private var connectionState: FeedConnectionState = .idle

    init(repository: any StockRepositoryProtocol, symbol: String) {
        self.repository = repository
        self.symbol = symbol
    }

    func activate() async {
        deactivate()

        let entries = await repository.catalog()
        catalogEntry = entries.first { $0.symbol == symbol }

        guard catalogEntry != nil else {
            uiModel = nil
            return
        }

        connectionState = repository.currentFeedConnectionState

        rebuildModel(quote: repository.currentMergedQuotes().first { $0.symbol == self.symbol })

        connectionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await state in repository.connectionEvents() {
                connectionState = state
                rebuildModel(quote: repository.currentMergedQuotes().first { $0.symbol == self.symbol })
            }
        }

        quoteTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await incoming in repository.quoteEvents() where incoming.symbol == self.symbol {
                scheduleCoalescedRebuild(quote: incoming)
            }
        }
    }

    func deactivate() {
        connectionTask?.cancel()
        connectionTask = nil
        quoteTask?.cancel()
        quoteTask = nil
        quoteCoalesceTask?.cancel()
        quoteCoalesceTask = nil
    }

    private func scheduleCoalescedRebuild(quote: StockQuote) {
        quoteCoalesceTask?.cancel()
        quoteCoalesceTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: QuoteStreamPresentationTiming.uiRefreshCoalesce)
            rebuildModel(quote: quote)
        }
    }

    private func rebuildModel(quote: StockQuote?) {
        guard let catalogEntry else {
            uiModel = nil
            return
        }

        let stale = stalePresentationActive()
        uiModel = StockUIMapper.detailUIModel(catalog: catalogEntry, quote: quote, stalePresentation: stale)
    }

    private func stalePresentationActive() -> Bool {
        let connectedLive = repository.isUserStreamingRequested && connectionState == .connected
        return connectedLive == false
    }
}
