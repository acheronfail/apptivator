//
//  ApplicationStateTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class ApplicationStateTests: XCTestCase {
    func testSequencesDoNotConflict() {
        let state = getTestState()
        let sequences = [
            (true, [ // Conflicts with "Xcode.app"
                shortcutView(withKeyCode: KEY_A, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_B, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_C, modifierFlags: CMD_SHIFT)
            ]),
            (true, [ // Conflicts with "Calculator.app"
                shortcutView(withKeyCode: KEY_A, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_D, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_A, modifierFlags: CMD_SHIFT)
            ]),
            (true, [ // Conflicts with "Chess.app"
                shortcutView(withKeyCode: KEY_D, modifierFlags: CMD_SHIFT)
            ]),
            (false, [
                shortcutView(withKeyCode: KEY_E, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_F, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_G, modifierFlags: CMD_SHIFT)
            ]),
        ]
        for (i, pair) in sequences.enumerated() {
            let (shouldConflict, sequence) = pair
            let didConflict = state.checkForConflictingSequence(sequence) != nil
            XCTAssert(didConflict == shouldConflict, "Incorrect assertion at index: \(i)")
        }
    }

    func testSequencesRegisterCorrectly() {
        let s = getTestState()
        var expected: [Bool]
        let shortcuts = [
            (KEY_A, CMD_SHIFT),
            (KEY_B, CMD_SHIFT),
            (KEY_C, CMD_SHIFT),
            (KEY_D, CMD_SHIFT),
            (KEY_E, CMD_SHIFT),
            (KEY_F, CMD_SHIFT),
            (KEY_G, CMD_SHIFT)
        ]

        // Initial.
        s.registerShortcuts(atIndex: 0, last: nil)
        expected = [true, false, false, true, false, false, true]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })

        // Xcode shortcut #1.
        s.registerShortcuts(atIndex: 1, last: (KEY_A, CMD_SHIFT))
        expected = [false, true, false, true, false, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })

        // Xcode shortcut #2. This is when the sequence is complete, so this should never really be
        // called - it should reset at this point. Just check that no other shortcuts are registered.
        s.registerShortcuts(atIndex: 2, last: (KEY_B, CMD_SHIFT))
        expected = [false, false, false, false, false, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })

        // Initial, again.
        s.registerShortcuts(atIndex: 0, last: nil)
        expected = [true, false, false, true, false, false, true]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })

        // System Preferences.app shortcut #1.
        s.registerShortcuts(atIndex: 1, last: (KEY_G, CMD_SHIFT))
        expected = [false, false, false, false, false, true, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })

        // System Preferences.app shortcut #2.
        s.registerShortcuts(atIndex: 2, last: (KEY_F, CMD_SHIFT))
        expected = [false, false, false, false, true, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered(s, $0.0, $0.1) == $1) })
    }

    func testSaveAndLoadToDisk() {
        let path = getTemporaryFilePath()

        // Create a state and make changes to it.
        let a = ApplicationState(atPath: path)
        a.isEnabled = false
        a.darkModeEnabled = true
        let entryOne = entry(atURL: URL(fileURLWithPath: "/Applications/Xcode.app"), sequence: [shortcutView(withKeyCode: 120, modifierFlags: 0)])
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
    }

    func isShortcutRegistered(_ state: ApplicationState, _ keyCode: UInt, _ modifierFlags: UInt) -> Bool {
        return state.monitor.isShortcutRegistered(MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags))
    }

    func getTemporaryFilePath() -> URL {
        return URL(fileURLWithPath: "\(NSTemporaryDirectory())config.json")
    }

    func getTestState() -> ApplicationState {
        let state = ApplicationState(atPath: getTemporaryFilePath())
        state.entries.append(contentsOf: [
            entry(atURL: URL(fileURLWithPath: "/Applications/Xcode.app"), sequence: [
                shortcutView(withKeyCode: KEY_A, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_B, modifierFlags: CMD_SHIFT)
            ]),
            entry(atURL: URL(fileURLWithPath: "/Applications/Calculator.app"), sequence: [
                shortcutView(withKeyCode: KEY_A, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_D, modifierFlags: CMD_SHIFT)
            ]),
            entry(atURL: URL(fileURLWithPath: "/Applications/Chess.app"), sequence: [
                shortcutView(withKeyCode: KEY_D, modifierFlags: CMD_SHIFT)
            ]),
            entry(atURL: URL(fileURLWithPath: "/Applications/System Preferences.app"), sequence: [
                shortcutView(withKeyCode: KEY_G, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_F, modifierFlags: CMD_SHIFT),
                shortcutView(withKeyCode: KEY_E, modifierFlags: CMD_SHIFT)
            ])
        ])
        return state
    }
}
