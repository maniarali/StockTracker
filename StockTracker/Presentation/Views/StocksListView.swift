//
//  StocksListView.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import StockTrackerDomain
import SwiftUI

struct StocksListView: View {
    @Bindable private var screenModel: StocksScreenModel
    @Binding private var path: NavigationPath
    private let resolvedDark: Bool
    private let toggleAppearance: () -> Void

    init(screenModel: StocksScreenModel, path: Binding<NavigationPath>, resolvedDark: Bool, toggleAppearance: @escaping () -> Void) {
        _screenModel = Bindable(screenModel)
        _path = path
        self.resolvedDark = resolvedDark
        self.toggleAppearance = toggleAppearance
    }

    var body: some View {
        Group {
            if let failure = screenModel.failurePresentation {
                StockMessageView(presentation: failure, palette: palette, onRetry: {
                    Task { @MainActor in
                        await screenModel.retryAfterFailure()
                    }
                })
            } else if screenModel.onboardingActive {
                StockMessageView(presentation: .startSocketOnboarding, palette: palette)
            } else {
                List(screenModel.rows) { row in
                    Button {
                        path.append(StockNavigationRoute.detail(symbol: row.symbol))
                    } label: {
                        StockRowView(row: row, palette: palette)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stock.row.\(row.symbol)")
                    .accessibilityHint(Text(LocalizedStringKey("a11y.stock_row.hint")))
                }
                .listStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: screenModel.rows)
            }
        }
        .navigationTitle(Text(LocalizedStringKey("app.title")))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ConnectionIndicatorView(state: screenModel.connectionState, palette: palette)
                    .accessibilityIdentifier("connection.indicator")
                    .id(connectionStateRefreshID(screenModel.connectionState))
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: toggleAppearance) {
                    Image(systemName: resolvedDark ? "moon.fill" : "moon")
                        .accessibilityIdentifier("toolbar.theme_toggle")
                }
                .accessibilityLabel(Text(LocalizedStringKey("a11y.theme_toggle")))

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            screenModel.sortOption = option
                        } label: {
                            Text(LocalizedStringKey(option.localizationKey))
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .accessibilityIdentifier("toolbar.sort")
                }
                .accessibilityLabel(Text(LocalizedStringKey("a11y.sort_menu")))

                Button {
                    Task { @MainActor in
                        if screenModel.isStreamingRequested {
                            await screenModel.stopStreaming()
                        } else {
                            await screenModel.startStreaming()
                        }
                    }
                } label: {
                    Image(systemName: screenModel.isStreamingRequested ? "stop.fill" : "play.fill")
                        .accessibilityIdentifier("toolbar.feed_toggle")
                }
                .accessibilityLabel(
                    screenModel.isStreamingRequested
                        ? Text(LocalizedStringKey("a11y.feed_stop"))
                        : Text(LocalizedStringKey("a11y.feed_start"))
                )
            }
        }
    }

    @Environment(\.stockPalette) private var palette

    private func connectionStateRefreshID(_ state: FeedConnectionState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case let .reconnecting(attempt):
            return "reconnecting.\(attempt)"
        case .stopped:
            return "stopped"
        case let .failed(reason):
            return "failed.\(String(describing: reason))"
        }
    }
}

private struct ConnectionIndicatorView: View {
    let state: FeedConnectionState
    let palette: StockPalette

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 10, height: 10)
            .accessibilityLabel(Text(verbatim: accessibilityKey))
    }

    private var indicatorColor: Color {
        switch state {
        case .connected:
            return palette.positive
        case .connecting, .reconnecting:
            return Color.orange
        case .failed:
            return palette.negative
        case .idle, .stopped:
            return palette.secondaryText.opacity(0.45)
        }
    }

    private var accessibilityKey: String {
        switch state {
        case .connected:
            return String(localized: String.LocalizationValue("connection.connected"))
        case .connecting:
            return String(localized: String.LocalizationValue("connection.connecting"))
        case .reconnecting:
            return String(localized: String.LocalizationValue("connection.reconnecting"))
        case .failed:
            return String(localized: String.LocalizationValue("connection.failed"))
        case .stopped:
            return String(localized: String.LocalizationValue("connection.stopped"))
        case .idle:
            return String(localized: String.LocalizationValue("connection.idle"))
        }
    }
}

private struct StockRowView: View {
    let row: StockRowUIModel
    let palette: StockPalette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StockSymbolAvatarView(symbol: row.symbol, companyName: row.companyName, diameter: 42, palette: palette)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.symbol)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(row.companyName)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.priceText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(row.movementPositive ? palette.positive : palette.negative)

                HStack(spacing: 6) {
                    Image(systemName: row.movementPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.caption2.weight(.bold))

                    Text(row.movementLine)
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(row.movementPositive ? palette.positive : palette.negative)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryText.opacity(0.35))
        }
        .padding(.vertical, 6)
        .opacity(row.stalePresentation ? palette.staleOpacity : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stockRowAccessibilityLabel(row))
    }

    private func stockRowAccessibilityLabel(_ row: StockRowUIModel) -> String {
        String(
            format: String(localized: String.LocalizationValue("a11y.stock_row.label")),
            locale: Locale.current,
            row.companyName as CVarArg,
            row.symbol as CVarArg,
            row.priceText as CVarArg,
            row.movementLine as CVarArg
        )
    }
}

#Preview("Stock row") {
    StockRowView(
        row: StockRowUIModel(
            symbol: "AAPL",
            companyName: "Apple Inc.",
            priceText: "$242.15",
            movementLine: "+$1.20 (+0.50%)",
            movementPositive: true,
            stalePresentation: false
        ),
        palette: StockPalette.palette(for: .light)
    )
    .padding()
}
