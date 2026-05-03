//
//  RootStockTrackerView.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import StockTrackerDomain
import SwiftUI

struct RootStockTrackerView: View {
    private let repository: any StockRepositoryProtocol
    private let feedLifecycle: StockFeedLifecycleControlling

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var screenModel: StocksScreenModel
    @State private var path = NavigationPath()
    @State private var prefersDarkAppearance: Bool?

    init(repository: any StockRepositoryProtocol) {
        self.repository = repository
        let lifecycle = StockFeedLifecycleService(repository: repository)
        feedLifecycle = lifecycle
        _screenModel = State(initialValue: StocksScreenModel(repository: repository, feedLifecycle: lifecycle))
    }

    var body: some View {
        let paletteScheme: ColorScheme = resolvedDark ? .dark : .light
        let palette = StockPalette.palette(for: paletteScheme)

        NavigationStack(path: $path) {
            StocksListView(
                screenModel: screenModel,
                path: $path,
                resolvedDark: resolvedDark,
                toggleAppearance: toggleAppearance
            )
            .navigationDestination(for: StockNavigationRoute.self) { route in
                switch route {
                case let .detail(symbol):
                    StockDetailView(repository: repository, symbol: symbol)
                }
            }
        }
        .environment(\.stockPalette, palette)
        .preferredColorScheme(preferredSystemScheme)
        .task {
            await screenModel.activate()
        }
        .task {
            await feedLifecycle.observeReachabilityForAutomaticFeedRecovery()
        }
        .task(id: scenePhase) {
            await repository.applySceneActivity(scenePhase == .active ? .active : .inactive)
        }
    }

    private var resolvedDark: Bool {
        if let prefersDarkAppearance {
            return prefersDarkAppearance
        }

        return colorScheme == .dark
    }

    private var preferredSystemScheme: ColorScheme? {
        guard let prefersDarkAppearance else {
            return nil
        }

        return prefersDarkAppearance ? .dark : .light
    }

    private func toggleAppearance() {
        if let prefersDarkAppearance {
            self.prefersDarkAppearance = prefersDarkAppearance == false
        } else {
            prefersDarkAppearance = colorScheme == .dark ? false : true
        }
    }
}
