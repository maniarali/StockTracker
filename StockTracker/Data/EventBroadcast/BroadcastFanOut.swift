//
//  BroadcastFanOut.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation
import Synchronization

/// Thread-safe multi-subscriber fan-out. Methods are `nonisolated` so teardown can call `finishAll()` from `deinit`
/// while the app target uses `default actor isolation = MainActor`.
final class BroadcastFanOut<Element: Sendable>: Sendable {
    private struct Registration {
        let id: UUID
        let continuation: AsyncStream<Element>.Continuation
    }

    private struct LockedState {
        var registrations: [UUID: Registration] = [:]
    }

    private let mutex = Mutex(LockedState())

    nonisolated func makeStream(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(64)
    ) -> AsyncStream<Element> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let id = UUID()
            let registration = Registration(id: id, continuation: continuation)
            mutex.withLock { state in
                state.registrations[id] = registration
            }

            continuation.onTermination = { @Sendable [self] _ in
                self.mutex.withLock { state in
                    _ = state.registrations.removeValue(forKey: id)
                }
            }
        }
    }

    nonisolated func yield(_ element: Element) {
        let snapshots = mutex.withLock { state -> [Registration] in
            Array(state.registrations.values)
        }

        for registration in snapshots {
            registration.continuation.yield(element)
        }
    }

    nonisolated func finishAll() {
        let snapshots = mutex.withLock { state -> [Registration] in
            let copied = Array(state.registrations.values)
            state.registrations.removeAll()
            return copied
        }

        for registration in snapshots {
            registration.continuation.finish()
        }
    }
}
