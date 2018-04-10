//
//  ApplicationStateTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class ApplicationStateTests: XCTestCase {
    func testSaveAndLoadToDisk() {
        let path = getTemporaryFilePath()

        // Create a state and make changes to it.
        let a = ApplicationState(atPath: path)
        a.isEnabled = false
        a.darkModeEnabled = true
        let entryOne = ApplicationEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)!
        entryOne.shortcutView.shortcutValue = MASShortcut(keyCode: 120 /* F2 */, modifierFlags: 0)
        let entryTwo = ApplicationEntry(url: URL(fileURLWithPath: "/Applications/Calculator.app"), config: nil)!
        entryTwo.config.launchIfNotRunning = true
        entryTwo.config.hideWhenDeactivated = true
        entryTwo.config.showOnScreenWithMouse = true
        entryTwo.config.hideWithShortcutWhenActive = true
        a.entries.append(entryOne)
        a.entries.append(entryTwo)
        // Write it to disk.
        a.saveToDisk()

        // Create another state at the same path, and load it from disk.
        let b = ApplicationState(atPath: path)
        b.loadFromDisk()

        // Compare the two states for equality.
        XCTAssert(a.isEnabled == b.isEnabled)
        XCTAssert(a.entries.count == a.entries.count)
        XCTAssert(a.darkModeEnabled == b.darkModeEnabled)
        for i in (0..<a.entries.count) {
            XCTAssert(a.entries[i].name == b.entries[i].name)
        }

        entryOne.dealloc()
        entryTwo.dealloc()
    }

    func getTemporaryFilePath() -> URL {
        return URL(fileURLWithPath: (NSTemporaryDirectory() as String) + "config.json")
    }
}
