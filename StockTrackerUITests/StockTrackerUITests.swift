//
//  StockTrackerUITests.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import XCTest

final class StockTrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsHomeNavigationTitle() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
}
