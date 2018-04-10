//
//  ApplicationEntryTests.swift
//  ApptivatorTests
//

import XCTest
import SwiftyJSON

@testable import Apptivator

class ApplicationEntryTests: XCTestCase {
    // Since ApplicationEntry instances have some closures associated with them, it's a good idea to
    // ensure that they're cleaned up once they go out of scope to prevent memory leaks.
    func testEntryIsDeinitialised() {
        // Add a hook into the instance's `deinit` block.
        class MockEntry: ApplicationEntry {
            var deinitCalled: (() -> Void)?
            deinit { deinitCalled!() }
        }

        let expectation = self.expectation(description: "deinit")
        expectation.expectedFulfillmentCount = 2

        // Place tests within blocks so they go out of scope afterwards.
        do {
            let entry = MockEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)!
            XCTAssert(entry.isActive == true)
            XCTAssert(entry.shortcutView.shortcutValueChange == nil)
            entry.deinitCalled = { expectation.fulfill() }
            entry.unregister()
        }
        do {
            let data = "{\"url\":\"file:///Applications/Xcode.app\",\"keyCode\":120,\"modifierFlags\":0}".data(using: .utf8, allowLossyConversion: false)!
            let entry = try MockEntry(json: try JSON(data: data))!
            entry.deinitCalled = { expectation.fulfill() }
            entry.unregister()
        } catch { XCTFail(error.localizedDescription) }

        self.waitForExpectations(timeout: 0.0, handler: nil)
    }

    func testDoesNotUseValueFromDefaults() {
        let url = URL(fileURLWithPath: "/Applications/Xcode.app")
        let key = ApplicationEntry.generateKey(for: url)

        let shortcut = MASShortcut(keyCode: 120 /* F2 */, modifierFlags: 0)
        let shortcutData = NSKeyedArchiver.archivedData(withRootObject: shortcut as Any)
        UserDefaults.standard.set(shortcutData, forKey: key)

        let entry = ApplicationEntry(url: url, config: nil)!
        XCTAssert(entry.shortcutView.shortcutValue == nil)

        UserDefaults.standard.removeObject(forKey: key)
    }

    func testSerialisesAndDeserialises() {
        let entriesBefore = getSampleEntries()
        let json = ApplicationEntry.serialiseList(entries: entriesBefore)
        let entriesAfter = ApplicationEntry.deserialiseList(fromJSON: json)
        for i in (0..<entriesBefore.count) {
            let a = entriesBefore[i]
            let b = entriesAfter[i]
            XCTAssert(a.url == b.url)
            XCTAssert(a.key == b.key)
            XCTAssert(a.name == b.name)
            XCTAssert(a.config == b.config)
            XCTAssert(a.shortcutAsString == b.shortcutAsString)
            a.unregister()
            b.unregister()
        }
    }

    func testShortcutStrings() {
        let shortcutStrings = ["nil", "⇧⌘S", "F2"]
        for (i, entry) in getSampleEntries().enumerated() {
            XCTAssert(entry.shortcutAsString == shortcutStrings[i])
        }
    }

    func getSampleEntries() -> [ApplicationEntry] {
        do {
            return try [
                "{\"url\":\"file:///Applications/Xcode.app\",\"config\":{\"showOnScreenWithMouse\":true}}",
                "{\"url\":\"file:///Applications/Chess.app\",\"keyCode\":1,\"modifierFlags\":1179648}",
                "{\"url\":\"file:///Applications/Calculator.app\",\"keyCode\":120,\"modifierFlags\":0}",
            ]
                .map({ try JSON(data: $0.data(using: .utf8, allowLossyConversion: false)!) })
                .map({ try ApplicationEntry(json: $0)! })
        } catch {
            XCTFail(error.localizedDescription)
        }

        return []
    }
}
