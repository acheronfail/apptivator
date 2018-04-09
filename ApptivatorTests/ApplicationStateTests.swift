//
//  ApplicationStateTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class ApplicationStateTests: XCTestCase {
    func testSaveAndLoadToDisk() {
        let path = temporaryFilePath()

        // Create a state and make changes to it.
        let a = ApplicationState(atPath: path)
        a.isEnabled = false
        a.darkModeEnabled = true
        let entryOne = ApplicationEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)!
        entryOne.shortcutCell.shortcutValue = MASShortcut(keyCode: 120 /* F2 */, modifierFlags: 0)
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
            let lhs = a.entries[i]
            let rhs = b.entries[i]
            XCTAssert(lhs.url == rhs.url)
            XCTAssert(lhs.key == rhs.key)
            XCTAssert(lhs.name == rhs.name)
            XCTAssert(lhs.config == rhs.config)
            XCTAssert(lhs.shortcutAsString == rhs.shortcutAsString)
        }
    }

    func temporaryFilePath() -> URL {
        return URL(fileURLWithPath: (NSTemporaryDirectory() as String) + "config.json")
    }
}
