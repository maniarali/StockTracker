//
//  StockMessageView.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import SwiftUI

struct StockMessageView: View {
    private let presentation: MessagePresentation
    private let palette: StockPalette
    private let onRetry: (() -> Void)?

    init(presentation: MessagePresentation, palette: StockPalette, onRetry: (() -> Void)? = nil) {
        self.presentation = presentation
        self.palette = palette
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(palette.secondaryText)

            Text(LocalizedStringKey(presentation.titleKey))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.primaryText)

            Text(LocalizedStringKey(presentation.bodyKey))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.secondaryText)

            if presentation.showsRetry, let onRetry {
                Button(action: onRetry) {
                    Text(LocalizedStringKey("message.retry"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.screenBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: "%@. %@",
                String(localized: String.LocalizationValue(presentation.titleKey)),
                String(localized: String.LocalizationValue(presentation.bodyKey))
            )
        )
    }
}
