//
//  MessagePresentationMapper.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import StockTrackerDomain

nonisolated enum MessagePresentationMapper {
    static func map(failure: FeedFailure) -> MessagePresentation {
        switch failure {
        case .transportUnavailable:
            return .feedTransportFailure
        case .decodingFailed:
            return .feedDecodingFailure
        case .closedByServer:
            return .feedClosedFailure
        case .cancelled:
            return .feedCancelledFailure
        case .persistenceFailed:
            return .persistenceFailure
        }
    }
}
