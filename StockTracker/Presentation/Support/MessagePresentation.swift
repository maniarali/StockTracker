//
//  MessagePresentation.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation

nonisolated struct MessagePresentation: Equatable {
    let titleKey: String
    let bodyKey: String
    let symbolName: String
    let showsRetry: Bool

    static let catalogFailure = MessagePresentation(
        titleKey: "message.catalog_failure.title",
        bodyKey: "message.catalog_failure.body",
        symbolName: "exclamationmark.triangle.fill",
        showsRetry: false
    )

    static let persistenceFailure = MessagePresentation(
        titleKey: "message.persistence_failure.title",
        bodyKey: "message.persistence_failure.body",
        symbolName: "exclamationmark.triangle.fill",
        showsRetry: true
    )

    static let feedTransportFailure = MessagePresentation(
        titleKey: "message.socket_failure.title",
        bodyKey: "message.socket_failure.body",
        symbolName: "wifi.slash",
        showsRetry: true
    )

    static let feedDecodingFailure = MessagePresentation(
        titleKey: "message.decode_failure.title",
        bodyKey: "message.decode_failure.body",
        symbolName: "text.badge.xmark",
        showsRetry: true
    )

    static let feedClosedFailure = MessagePresentation(
        titleKey: "message.closed_failure.title",
        bodyKey: "message.closed_failure.body",
        symbolName: "bolt.slash.fill",
        showsRetry: true
    )

    static let feedCancelledFailure = MessagePresentation(
        titleKey: "message.cancelled_failure.title",
        bodyKey: "message.cancelled_failure.body",
        symbolName: "xmark.circle.fill",
        showsRetry: true
    )

    static let startSocketOnboarding = MessagePresentation(
        titleKey: "message.start_socket.title",
        bodyKey: "message.start_socket.body",
        symbolName: "antenna.radiowaves.left.and.right",
        showsRetry: false
    )
}
