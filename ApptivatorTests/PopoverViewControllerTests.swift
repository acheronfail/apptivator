//
//  PopoverViewControllerTests
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class PopoverViewControllerTests: XCTestCase {
    func testReopenCheckboxUpdatesSelectionAndShowsMixedValues() throws {
        resetState(withSampleEntries: false)
        defer { resetState(withSampleEntries: false) }
        let delegate = try XCTUnwrap(NSApp.delegate as? AppDelegate)
        let controller = try XCTUnwrap(delegate.popoverViewController)
        _ = controller.view
        let first = try XCTUnwrap(APAppEntry(url: fixtureURL("Calculator.app"), config: nil))
        let second = try XCTUnwrap(APAppEntry(url: fixtureURL("Chess.app"), config: ["reopenWhenNoWindows": true]))
        APState.shared.addEntry(first)
        APState.shared.addEntry(second)
        controller.tableView.reloadData()
        controller.tableView.selectRowIndexes(IndexSet(integersIn: 0..<2), byExtendingSelection: false)
        let button = try XCTUnwrap(controller.reopenWhenNoWindows)
        XCTAssertTrue(controller.getLocalConfigButtons().contains(button))
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.state, .mixed)
        button.state = .on
        controller.onLocalCheckboxChange(button)
        XCTAssertTrue(first.config.reopenWhenNoWindows)
        XCTAssertTrue(second.config.reopenWhenNoWindows)
        controller.tableView.selectRowIndexes([], byExtendingSelection: false)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.state, .off)
    }
}
