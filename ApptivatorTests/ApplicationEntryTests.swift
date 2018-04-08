//
//  ApplicationEntryTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class ApplicationEntryTests: XCTestCase {

    // Since ApplicationEntry instances have some closures associated with them, it's a good idea to
    // ensure that they're cleaned up once they go out of scope to prevent memory leaks.
    func testEntryIsDeinitialised() {
        // Add a hook into the instance's `deinit` block.
        class TestEntry: ApplicationEntry {
            var deinitCalled: (() -> Void)?
            deinit { deinitCalled!() }
        }

        let expectation = self.expectation(description: "deinit")

        // Create entry within block so it goes out of scope afterwards.
        do {
            let entry = TestEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)
            XCTAssert(entry != nil)
            XCTAssert(entry!.observer != nil)
            XCTAssert(entry!.shortcutCell.shortcutValueChange != nil)
            entry!.deinitCalled = { expectation.fulfill() }
        }

        self.waitForExpectations(timeout: 0.0, handler: nil)
    }
}
