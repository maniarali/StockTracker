//
//  EchoWebSocketSession.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public actor EchoWebSocketSession {
    private let url: URL
    private let symbols: [String]
    private let logger: EchoLogger?
    private let backoffPolicy: ExponentialBackoffPolicy
    private let outboundIntervalNanoseconds: UInt64
    private let handshakeTimeoutNanoseconds: UInt64
    private let tlsHooks: EchoTLSHooks
    private let transportMetrics: EchoTransportMetrics?
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private var workIntent: TransportWorkIntent = .userStopped
    private var reconnectAttempt = 0
    private var driverTask: Task<Void, Never>?
    private var urlSession: URLSession?
    private var urlSessionDelegate: EchoWebSocketURLSessionDelegate?
    private var socketTask: URLSessionWebSocketTask?
    private var linkState: TransportLinkState = .inactive
    private var outboundSuspended = false
    private var lastTradePrices: [String: Double] = [:]
    private var referenceClosePrices: [String: Double] = [:]
    private var pendingTerminalTransportFailure: WebSocketTransportFailure?
    private var urlSessionCompletion: URLSessionCompletionExpectation = .surfaceToDriver
    private var suppressDisconnectOnNextStop = false

    public init(
        url: URL,
        symbols: [String],
        outboundIntervalNanoseconds: UInt64,
        backoffPolicy: ExponentialBackoffPolicy,
        logger: EchoLogger?,
        tlsHooks: EchoTLSHooks = EchoTLSHooks(),
        transportMetrics: EchoTransportMetrics? = nil,
        handshakeTimeoutNanoseconds: UInt64 = 30_000_000_000,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
        self.url = url
        self.symbols = symbols
        self.logger = logger
        self.backoffPolicy = backoffPolicy
        self.outboundIntervalNanoseconds = outboundIntervalNanoseconds
        self.tlsHooks = tlsHooks
        self.transportMetrics = transportMetrics
        self.handshakeTimeoutNanoseconds = handshakeTimeoutNanoseconds
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }

    internal var handshakeTimeoutNanosecondsConfigured: UInt64 {
        handshakeTimeoutNanoseconds
    }

    public func wireEventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy = WebSocketPublicEventStreamDefaults.bufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.handleStreamTermination() }
            }
        }
    }

    public func start() {
        guard driverTask == nil else {
            return
        }
        workIntent = .streaming
        driverTask = Task {
            await self.runDriver()
        }
    }

    public func stop() async {
        workIntent = .userStopped
        let skipDisconnect = suppressDisconnectOnNextStop
        suppressDisconnectOnNextStop = false
        let task = driverTask
        driverTask = nil

        task?.cancel()

        teardownSocket()
        urlSession?.invalidateAndCancel()
        urlSession = nil
        urlSessionDelegate = nil

        reconnectAttempt = 0
        let cont = continuation

        if skipDisconnect == false {
            cont?.yield(.disconnected(userInitiated: true))
        }
        cont?.finish()
        continuation = nil

        logger?.info("Echo session stopped")
    }

    public func setOutboundSuspended(_ suspended: Bool) {
        outboundSuspended = suspended
    }

    nonisolated func urlSessionTaskDidComplete(error: Error?) {
        Task {
            await self.onURLSessionTaskCompleted(error: error)
        }
    }

    private func onURLSessionTaskCompleted(error: Error?) {
        linkState = .broken

        if workIntent == .userStopped {
            return
        }

        if urlSessionCompletion == .ignoreNextForScheduledReconnect {
            urlSessionCompletion = .surfaceToDriver
            return
        }

        guard shouldTreatTaskCompletionAsTransportLoss(error: error) else {
            return
        }

        if pendingTerminalTransportFailure == nil {
            pendingTerminalTransportFailure = .closedUnexpectedly
        }

        socketTask?.cancel(with: .goingAway, reason: nil)
    }

    private func shouldTreatTaskCompletionAsTransportLoss(error: Error?) -> Bool {
        if error == nil {
            return true
        }

        if error is CancellationError {
            return false
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return false
        }

        return true
    }

    private func handleStreamTermination() async {
        await stop()
    }

    private func emit(_ event: WebSocketPublicEvent) {
        continuation?.yield(event)
    }

    private func teardownSocket() {
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        linkState = .broken
    }

    private func requestTransportHalt(with failure: WebSocketTransportFailure) {
        if pendingTerminalTransportFailure == nil {
            pendingTerminalTransportFailure = failure
        }

        linkState = .broken
        socketTask?.cancel(with: .goingAway, reason: nil)
    }

    private func runDriver() async {
        defer {
            driverTask = nil
        }

        while !Task.isCancelled {
            switch workIntent {
            case .userStopped:
                return
            case .streaming:
                break
            }

            switch await openSocketSession() {
            case .handshook:
                break
            case .abortedBecauseUserStopped:
                emit(.disconnected(userInitiated: true))
                return
            case .handshakeFailed:
                let delay = backoffPolicy.delayNanoseconds(forAttempt: reconnectAttempt)
                reconnectAttempt += 1
                emit(.reconnectScheduled(attempt: reconnectAttempt))
                transportMetrics?.onReconnectSleep?(reconnectAttempt, delay)
                logger?.debug("Reconnect sleeping \(delay) ns attempt \(reconnectAttempt)")
                try? await Task.sleep(nanoseconds: delay)
                continue
            }

            reconnectAttempt = 0
            emit(.connected)

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.receiveLoop()
                }

                group.addTask {
                    await self.outboundLoop()
                }
            }

            let terminalFailure = pendingTerminalTransportFailure
            pendingTerminalTransportFailure = nil

            if let terminalFailure {
                teardownSocket()
                urlSession?.invalidateAndCancel()
                urlSession = nil
                urlSessionDelegate = nil
                suppressDisconnectOnNextStop = true
                transportMetrics?.onTerminalTransportFailure?(terminalFailure)
                emit(.transportFailure(terminalFailure))
                return
            }

            urlSessionCompletion = .ignoreNextForScheduledReconnect

            teardownSocket()
            urlSession?.invalidateAndCancel()
            urlSession = nil
            urlSessionDelegate = nil

            switch workIntent {
            case .userStopped:
                emit(.disconnected(userInitiated: true))
                return
            case .streaming:
                emit(.disconnected(userInitiated: false))
                let delay = backoffPolicy.delayNanoseconds(forAttempt: reconnectAttempt)
                reconnectAttempt += 1
                emit(.reconnectScheduled(attempt: reconnectAttempt))
                transportMetrics?.onReconnectSleep?(reconnectAttempt, delay)
                logger?.debug("Session ended; backoff \(delay) ns attempt \(reconnectAttempt)")
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private func openSocketSession() async -> HandshakeSessionOutcome {
        urlSession?.invalidateAndCancel()

        let handshake = WebSocketHandshakeAwaiter()
        let delegate = EchoWebSocketURLSessionDelegate(handshake: handshake, owner: self, tlsHooks: tlsHooks)

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false

        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: .main)
        let task = session.webSocketTask(with: url)

        urlSessionDelegate = delegate
        urlSession = session
        socketTask = task
        linkState = .active

        switch workIntent {
        case .userStopped:
            session.invalidateAndCancel()
            urlSession = nil
            urlSessionDelegate = nil
            socketTask = nil
            return .abortedBecauseUserStopped
        case .streaming:
            break
        }

        task.resume()

        let handshakeOutcome = await raceFirstHandshakeResult(handshake)
        switch handshakeOutcome {
        case .success:
            transportMetrics?.onHandshakeCompleted?(true)
        case .failure:
            transportMetrics?.onHandshakeCompleted?(false)
        }

        switch workIntent {
        case .userStopped:
            session.invalidateAndCancel()
            urlSession = nil
            urlSessionDelegate = nil
            socketTask = nil
            return .abortedBecauseUserStopped

        case .streaming:
            break
        }

        if case .failure(let error) = handshakeOutcome {
            logger?.debug("WebSocket handshake failed \(error.localizedDescription)")
            session.invalidateAndCancel()
            urlSession = nil
            urlSessionDelegate = nil
            socketTask = nil
            linkState = .broken
            return .handshakeFailed
        }

        return .handshook
    }

    private func raceFirstHandshakeResult(_ handshake: WebSocketHandshakeAwaiter) async -> Result<Void, Error> {
        let handshakeCap = handshakeTimeoutNanoseconds
        return await withTaskGroup(of: Result<Void, Error>.self) { group in
            group.addTask {
                await handshake.waitHandshakeResult()
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: handshakeCap)
                return .failure(URLError(.timedOut))
            }

            guard let first = await group.next() else {
                group.cancelAll()
                return .failure(URLError(.unknown))
            }

            group.cancelAll()
            return first
        }
    }

    private func shouldContinueIOPumps() -> Bool {
        switch workIntent {
        case .userStopped:
            return false
        case .streaming:
            return linkState == .active
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard shouldContinueIOPumps() else {
                break
            }

            guard let socketTask else {
                linkState = .broken
                break
            }

            do {
                let message = try await socketTask.receive()
                switch message {
                case let .string(text):
                    guard let data = text.data(using: .utf8) else {
                        requestTransportHalt(with: .decodingFailed)
                        break
                    }

                    await decodePayload(from: data)

                case let .data(data):
                    await decodePayload(from: data)

                @unknown default:
                    requestTransportHalt(with: .closedUnexpectedly)
                }
            } catch {
                logger?.error("Receive failed \(error.localizedDescription)")
                requestTransportHalt(with: .closedUnexpectedly)
            }
        }
    }

    private func decodePayload(from data: Data) async {
        do {
            let payload = try jsonDecoder.decode(EchoStockPayload.self, from: data)
            emit(.decodedTick(payload))
        } catch {
            requestTransportHalt(with: .decodingFailed)
        }
    }

    private func outboundLoop() async {
        while !Task.isCancelled {
            guard shouldContinueIOPumps() else {
                break
            }

            if outboundSuspended {
                try? await Task.sleep(nanoseconds: 250_000_000)
                continue
            }

            guard let socketTask else {
                linkState = .broken
                break
            }

            let payload = makeSyntheticPayload()

            do {
                let data = try jsonEncoder.encode(payload)
                guard let text = String(data: data, encoding: .utf8) else {
                    requestTransportHalt(with: .decodingFailed)
                    break
                }

                try await socketTask.send(.string(text))
            } catch {
                logger?.error("Send failed \(error.localizedDescription)")
                requestTransportHalt(with: .closedUnexpectedly)
                break
            }

            try? await Task.sleep(nanoseconds: outboundIntervalNanoseconds)
        }
    }

    private func makeSyntheticPayload() -> EchoStockPayload {
        guard let symbol = symbols.randomElement() else {
            let fallbackSymbol = "UNK"
            let price = Double.random(in: 50...900)
            lastTradePrices[fallbackSymbol] = price
            referenceClosePrices[fallbackSymbol] = price * Double.random(in: 0.94...1.02)
            let prev = referenceClosePrices[fallbackSymbol] ?? price
            return EchoStockPayload(symbol: fallbackSymbol, price: price, previousClose: prev, emittedAtEpoch: Date().timeIntervalSince1970)
        }

        let priorPrice = lastTradePrices[symbol] ?? Double.random(in: 55...920)
        let delta = Double.random(in: -6 ... 6)
        let price = max(1.5, priorPrice + delta)
        lastTradePrices[symbol] = price

        if referenceClosePrices[symbol] == nil {
            referenceClosePrices[symbol] = priorPrice * Double.random(in: 0.985...1.015)
        }

        let previousClose = referenceClosePrices[symbol] ?? priorPrice
        return EchoStockPayload(symbol: symbol, price: price, previousClose: previousClose, emittedAtEpoch: Date().timeIntervalSince1970)
    }
}

private enum TransportWorkIntent: Equatable {
    case streaming
    case userStopped
}

private enum TransportLinkState: Equatable {
    case inactive
    case active
    case broken
}

private enum HandshakeSessionOutcome: Equatable {
    case handshook
    case handshakeFailed
    case abortedBecauseUserStopped
}

private enum URLSessionCompletionExpectation: Equatable {
    case surfaceToDriver
    case ignoreNextForScheduledReconnect
}
