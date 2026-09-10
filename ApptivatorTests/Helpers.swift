//
//  Helpers.swift
//  ApptivatorTests
//

import XCTest
import MASShortcut
@testable import Apptivator

let KEY_A: Int = 0
let KEY_B: Int = 11
let KEY_C: Int = 8
let KEY_D: Int = 2
let KEY_E: Int = 14
let KEY_F: Int = 3
let KEY_G: Int = 5
let OPT: UInt = 524288
let CMD: UInt = 1048576
let CMD_SHIFT: UInt = 1179648

func shortcutView(withKeyCode keyCode: Int, modifierFlags: UInt) -> MASShortcutView {
    let shortcutView = MASShortcutView()
    shortcutView.shortcutValue = MASShortcut(keyCode: keyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: modifierFlags))
    return shortcutView
}

func entry(atURL url: URL, sequence: [MASShortcutView]) -> APAppEntry {
    let entry = APAppEntry(url: url, config: nil)!
    entry.sequence = sequence
    return entry
}

// Local fixtures keep tests independent of installed or running applications.
let fixtureDirectory: URL = {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ApptivatorTests-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["Xcode.app", "Calculator.app", "Chess.app", "System Preferences.app"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(name), withIntermediateDirectories: true)
        }
    } catch {
        XCTFail("Could not create test fixtures: \(error)")
    }
    return directory
}()

func fixtureURL(_ name: String) -> URL {
    return fixtureDirectory.appendingPathComponent(name)
}
