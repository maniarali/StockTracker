//
//  FeedURLConfigurationTests.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 04/05/2026.
//

import XCTest

@testable import StockTracker

final class FeedURLConfigurationTests: XCTestCase {
    func testBundleProvidesConfiguredWebSocketURL() {
        let url = FeedTransportConfiguration.makeDefaultSocketURL()
        XCTAssertEqual(url?.scheme, "wss")
        XCTAssertEqual(url?.host, "ws.postman-echo.com")
        XCTAssertTrue(url?.path.contains("raw") == true)
    }
}
