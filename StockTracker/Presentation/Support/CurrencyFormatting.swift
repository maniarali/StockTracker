//
//  CurrencyFormatting.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation

enum CurrencyFormatting {
    private static let cache = FormatterCache()

    static func currencyString(for decimal: Decimal) -> String {
        cache.currency.string(for: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)"
    }

    static func signedCurrencyString(for decimal: Decimal) -> String {
        let magnitude = abs(decimal)
        let formatted = currencyString(for: magnitude)
        if decimal > 0 {
            return "+\(formatted)"
        }
        if decimal < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    static func signedPercentString(for decimal: Decimal) -> String {
        let magnitude = abs(decimal)
        let formatter = cache.signedPercent
        let body = formatter.string(from: NSDecimalNumber(decimal: magnitude)) ?? "\(magnitude)"

        if decimal > 0 {
            return "+\(body)%"
        }
        if decimal < 0 {
            return "-\(body)%"
        }

        return "\(body)%"
    }

    /// `NumberFormatter` is not `Sendable`; instances are immutable after creation and reads occur from any thread.
    private final class FormatterCache: @unchecked Sendable {
        let currency: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()

        let signedPercent: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()
    }
}
