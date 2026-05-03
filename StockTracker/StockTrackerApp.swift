import SwiftData
import SwiftUI

@main
struct StockTrackerApp: App {
    private let bootstrap: ApplicationBootstrap.Phase

    init() {
        bootstrap = ApplicationBootstrap.make()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap {
                case let .failed(message):
                    StockMessageView(
                        presentation: message,
                        palette: StockPalette.palette(for: .light)
                    )

                case let .ready(repository, container):
                    RootStockTrackerView(repository: repository)
                        .modelContainer(container)
                }
            }
        }
    }
}
