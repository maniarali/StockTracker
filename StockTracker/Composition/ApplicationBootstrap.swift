//
//  ApplicationBootstrap.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation
import StockSocketKit
import StockTrackerDomain
import SwiftData

enum ApplicationBootstrap {
    enum Phase {
        case failed(MessagePresentation)
        case ready(repository: any StockRepositoryProtocol, container: ModelContainer)
    }

    @MainActor
    static func make(logger: Logging = OSLogStockLogger()) -> Phase {
        guard let socketURL = FeedTransportConfiguration.makeDefaultSocketURL() else {
            return .failed(MessagePresentation.feedTransportFailure)
        }

        let catalogEntries: [StockCatalogEntry]
        do {
            catalogEntries = try CatalogLoading.load(bundle: .main, logger: logger)
        } catch {
            return .failed(MessagePresentation.catalogFailure)
        }

        let schema = Schema([PersistedQuote.self])

        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.log(.error, "Model container bootstrap failed \(error.localizedDescription)")
            return .failed(MessagePresentation.persistenceFailure)
        }

        let context = ModelContext(container)
        let repository = DefaultStockRepository(
            modelContext: context,
            catalogEntries: catalogEntries,
            logging: logger,
            echoFeedBuilder: { symbols in
                return EchoWebSocketSession(
                    url: socketURL,
                    symbols: symbols,
                    outboundIntervalNanoseconds: FeedTransportConfiguration.outboundPulseIntervalNanoseconds,
                    backoffPolicy: FeedTransportConfiguration.defaultBackoffPolicy,
                    logger: LoggingEchoBridge(logging: logger)
                )
            }
        )

        return .ready(repository: repository, container: container)
    }
}
