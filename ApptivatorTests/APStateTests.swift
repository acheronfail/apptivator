//
//  APStateTests.swift
//  ApptivatorTests
//

import XCTest

@testable import Apptivator

class APStateTests: XCTestCase {
    func testSequencesDoNotConflict() {
        resetState(withSampleEntries: true)
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
            let didConflict = APState.shared.checkForConflictingSequence(sequence, excluding: nil) != nil
            XCTAssert(didConflict == shouldConflict, "Incorrect assertion at index: \(i)")
        }
    }

    func testSequencesRegisterCorrectly() {
        resetState(withSampleEntries: true)
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
        APState.shared.registerShortcuts(atIndex: 0, last: nil)
        expected = [true, false, false, true, false, false, true]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })

        // Xcode shortcut #1.
        APState.shared.registerShortcuts(atIndex: 1, last: (KEY_A, CMD_SHIFT))
        expected = [false, true, false, true, false, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })

        // Xcode shortcut #2. This is when the sequence is complete, so this should never really be
        // called - it should reset at this point. Just check that no other shortcuts are registered.
        APState.shared.registerShortcuts(atIndex: 2, last: (KEY_B, CMD_SHIFT))
        expected = [false, false, false, false, false, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })

        // Initial, again.
        APState.shared.registerShortcuts(atIndex: 0, last: nil)
        expected = [true, false, false, true, false, false, true]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })

        // System Preferences.app shortcut #1.
        APState.shared.registerShortcuts(atIndex: 1, last: (KEY_G, CMD_SHIFT))
        expected = [false, false, false, false, false, true, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })

        // System Preferences.app shortcut #2.
        APState.shared.registerShortcuts(atIndex: 2, last: (KEY_F, CMD_SHIFT))
        expected = [false, false, false, false, true, false, false]
        zip(shortcuts, expected).forEach({ XCTAssert(isShortcutRegistered($0.0, $0.1) == $1) })
    }

    func testSaveAndLoadToDisk() {
        resetState(withSampleEntries: false)

        // Make changes to the state.
        APState.shared.isEnabled = false
        APState.shared.darkModeEnabled = true
        APState.shared.addEntry(entry(atURL: URL(fileURLWithPath: "/Applications/Xcode.app"), sequence: [shortcutView(withKeyCode: 120, modifierFlags: 0)]))
        APState.shared.addEntry(APAppEntry(url: URL(fileURLWithPath: "/Applications/Calculator.app"), config: nil)!)

        // Write to disk.
        APState.shared.saveToDisk()
        // Save written json.
        do {
            let savePath = APState.shared.savePath
            let newPath = URL(fileURLWithPath: savePath.path + ".backup")
            if FileManager.default.fileExists(atPath: newPath.path) {
                try FileManager.default.removeItem(at: newPath)
            }
            try FileManager.default.copyItem(at: savePath, to: newPath)

            // Reset state (this clears the file).
            resetState(withSampleEntries: false)

            // Rewrite json.
            if FileManager.default.fileExists(atPath: savePath.path) {
                try FileManager.default.removeItem(at: savePath)
            }
            try FileManager.default.copyItem(at: newPath, to: savePath)
        } catch {
            XCTFail(error.localizedDescription)
        }

        // Reload from disk.
        APState.shared.loadFromDisk()

        // Compare the two states for equality.
        XCTAssert(APState.shared.darkModeEnabled == true)
        XCTAssert(APState.shared.getEntries().count == 2)
    }

    func isShortcutRegistered(_ keyCode: UInt, _ modifierFlags: UInt) -> Bool {
        return APState.shared.monitor.isShortcutRegistered(MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags))
    }

    func getTemporaryFilePath() -> URL {
        return URL(fileURLWithPath: "\(NSTemporaryDirectory())config.json")
    }
}

func resetState(withSampleEntries: Bool) {
    // Clear the application state (write an empty file to load it from).
    do {
        try "{}".write(to: APState.shared.savePath, atomically: false, encoding: .utf8)
    } catch {
        XCTFail(error.localizedDescription)
    }
    APState.shared.loadFromDisk()
    if withSampleEntries {
        [
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
        ].forEach({ APState.shared.addEntry($0) })
    }
}
