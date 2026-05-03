//
//  StockDetailView.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import StockTrackerDomain
import SwiftUI

struct StockDetailView: View {
    private let repository: any StockRepositoryProtocol
    private let symbol: String

    @State private var model: StockDetailViewModel

    init(repository: any StockRepositoryProtocol, symbol: String) {
        self.repository = repository
        self.symbol = symbol
        _model = State(initialValue: StockDetailViewModel(repository: repository, symbol: symbol))
    }

    var body: some View {
        Group {
            if let uiModel = model.uiModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(uiModel: uiModel)

                        priceSection(uiModel: uiModel)

                        figuresSection(uiModel: uiModel)

                        Text(uiModel.descriptionText)
                            .font(.body)
                            .foregroundStyle(palette.secondaryText)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .opacity(uiModel.stalePresentation ? palette.staleOpacity : 1)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(palette.screenBackground)
        .navigationTitle(Text(symbol))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.activate()
        }
        .onDisappear {
            model.deactivate()
        }
    }

    @Environment(\.stockPalette) private var palette

    private func header(uiModel: StockDetailUIModel) -> some View {
        HStack(alignment: .center, spacing: 14) {
            StockSymbolAvatarView(symbol: uiModel.symbol, companyName: uiModel.companyName, diameter: 56, palette: palette)

            VStack(alignment: .leading, spacing: 8) {
                Text(uiModel.companyName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(uiModel.symbol)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.groupedSurface)
                    .clipShape(Capsule())
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func priceSection(uiModel: StockDetailUIModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("detail.last_price"))
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)

            Text(uiModel.lastPriceText)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(uiModel.movementPositive ? palette.positive : palette.negative)

            Text(LocalizedStringKey("detail.movement"))
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 8) {
                Image(systemName: uiModel.movementPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption.weight(.bold))

                Text(uiModel.movementLine)
                    .font(.headline.monospacedDigit())
            }
            .foregroundStyle(uiModel.movementPositive ? palette.positive : palette.negative)
        }
        .accessibilityElement(children: .combine)
    }

    private func figuresSection(uiModel: StockDetailUIModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("detail.key_figures"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                figureRow(titleKey: "detail.previous_close", valueText: uiModel.previousCloseText, emphasisPositive: nil)
                Divider()
                figureRow(titleKey: "detail.day_change", valueText: uiModel.dayChangeText, emphasisPositive: uiModel.movementPositive)
                Divider()
                figureRow(
                    titleKey: "detail.day_change_pct",
                    valueText: uiModel.dayChangePercentText,
                    emphasisPositive: uiModel.movementPositive
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.groupedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private func figureRow(titleKey: String, valueText: String, emphasisPositive: Bool?) -> some View {
        HStack {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(palette.secondaryText)

            Spacer()

            Text(valueText)
                .font(.body.monospacedDigit())
                .foregroundStyle(color(for: emphasisPositive))
        }
        .padding(.vertical, 10)
    }

    private func color(for emphasisPositive: Bool?) -> Color {
        guard let emphasisPositive else {
            return palette.primaryText
        }

        return emphasisPositive ? palette.positive : palette.negative
    }
}
