// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockTrackerDomain",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "StockTrackerDomain", targets: ["StockTrackerDomain"])
    ],
    targets: [
        .target(
            name: "StockTrackerDomain",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StockTrackerDomainTests",
            dependencies: ["StockTrackerDomain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
