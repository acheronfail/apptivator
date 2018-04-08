//
//  ApplicationEntryTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class ApplicationEntryTests: XCTestCase {
    func testEntryIsDeinitialised() {
        class TestEntry: ApplicationEntry {
            var deinitCalled: (() -> Void)?
            deinit { deinitCalled!() }
        }

        let expectation = XCTestExpectation(description: "deinit")
        expectation.expectedFulfillmentCount = 1

        // Create entry within block so it's cleaned up after the block.
        do {
            let entry = TestEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)
            XCTAssert(entry != nil)
            XCTAssert(entry!.observer != nil)
            entry!.deinitCalled = {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.0)
    }
}
