//
//  ExponentialBackoff.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public struct ExponentialBackoffPolicy: Sendable {
    public let initialNanoseconds: UInt64
    public let multiplier: Double
    public let maxNanoseconds: UInt64
    public let jitterRatio: Double

    public init(
        initialNanoseconds: UInt64,
        multiplier: Double,
        maxNanoseconds: UInt64,
        jitterRatio: Double
    ) {
        self.initialNanoseconds = initialNanoseconds
        self.multiplier = multiplier
        self.maxNanoseconds = maxNanoseconds
        self.jitterRatio = jitterRatio
    }

    public func delayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        let boundedAttempt = max(0, attempt)
        let raw = Double(initialNanoseconds) * pow(multiplier, Double(boundedAttempt))
        let capped = min(raw, Double(maxNanoseconds))
        let jitterPortion = capped * jitterRatio
        let jitter = Double.random(in: (-jitterPortion)...jitterPortion)
        let result = max(0, capped + jitter)
        return UInt64(result)
    }
}
