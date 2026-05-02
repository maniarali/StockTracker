import Foundation
import Network
import StockTrackerDomain

@MainActor
protocol StockFeedLifecycleControlling: AnyObject {
    func startUserStreaming() async
    func stopUserStreaming() async
    func restartUserFeedTransport() async
    func observeReachabilityForAutomaticFeedRecovery() async
}

@MainActor
final class StockFeedLifecycleService: StockFeedLifecycleControlling {
    private let repository: any StockRepositoryProtocol

    init(repository: any StockRepositoryProtocol) {
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

    func observeReachabilityForAutomaticFeedRecovery() async {
        let resume = ReachabilityFeedResumeBridge()
        resume.repository = repository

        var lastSatisfied: Bool?
        for await path in Self.networkPathUpdates() {
            guard !Task.isCancelled else {
                break
            }
            let satisfied = path.status == .satisfied
            guard satisfied != lastSatisfied else {
                continue
            }
            lastSatisfied = satisfied
            if satisfied {
                resume.notifyPathSatisfied()
            }
        }
    }

    private nonisolated static func networkPathUpdates() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.stocktracker.reachability.feed")

            monitor.pathUpdateHandler = { path in
                continuation.yield(path)
            }

            monitor.start(queue: queue)

            continuation.onTermination = { _ in
                monitor.cancel()
            }
        }
    }
}

private final class ReachabilityFeedResumeBridge {
    weak var repository: (any StockRepositoryProtocol)?

    func notifyPathSatisfied() {
        Task { @MainActor [weak self] in
            guard let repository = self?.repository else {
                return
            }
            await repository.ensureFeedTransportMountedIfNeeded()
        }
    }
}
