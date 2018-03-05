//
//  ApplicationEntry.swift
//  Apptivator
//

import Cocoa
import AXSwift
import SwiftyJSON
import MASShortcut

// Amount of time (in seconds) to wait after launching an applicaton until attempting
// to attach listeners to it.
let APP_LAUNCH_DELAY = 2.0

// Represents an item in the Shortcut table of the app's window.
// Each ApplicationEntry is simply a URL of an app mapped to a shortcut.
class ApplicationEntry: CustomDebugStringConvertible {

    // Where the app -> shortcut mappings are stored.
    static let entrySavePath = URL(fileURLWithPath: "/Users/acheronfail/Desktop/output.json")

    let name: String
    let key: String
    let icon: NSImage
    let url: URL
    let shortcutCell: MASShortcutView
    var observer: Observer?

    init(url: URL, name: String, icon: NSImage, shortcut: MASShortcut) {
        self.name = name
        self.icon = icon
        self.url = url
        self.shortcutCell = MASShortcutView()

        let key = ApplicationEntry.createApplicationEntryKey(url)
        self.key = key
        self.shortcutCell.associatedUserDefaultsKey = key

        self.shortcutCell.shortcutValueChange = onShortcutValueChange
    }

    init?(json: JSON) throws {
        self.url = json["url"].url!
        let properties = try (self.url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
        self.name = properties[.localizedNameKey] as? String ?? json["name"].string ?? ""
        self.icon = properties[.effectiveIconKey] as? NSImage ?? NSImage()

        let key = ApplicationEntry.createApplicationEntryKey(self.url)
        self.key = key
        self.shortcutCell = MASShortcutView()
        self.shortcutCell.associatedUserDefaultsKey = key

        self.shortcutCell.shortcutValueChange = onShortcutValueChange
        let shortcut = MASShortcut(keyCode: json["keyCode"].uInt!, modifierFlags: json["modifierFlags"].uInt!)
        self.shortcutCell.shortcutValue = shortcut
    }

    func onShortcutValueChange(_ sender: MASShortcutView?) -> () {
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: self.key, toAction: {
            if appIsEnabled && UIElement.isProcessTrusted(withPrompt: true) {
                if let app = findRunningApp(withURL: self.url) {
                    if app.isActive {
                        app.hide()
                    } else {
                        app.unhide()
                        app.activate(options: .activateIgnoringOtherApps)
                        self.createObserver(app)
                    }
                } else {
                    // Launch the application if it's not running, and after a delay attempt to
                    // create an observer to watch it for events. We have to wait since we cannot
                    // start observing an application if it hasn't fully launched.
                    var runningApp = launchApplication(at: self.url)
                    DispatchQueue.main.asyncAfter(deadline: .now() + APP_LAUNCH_DELAY) {
                        if runningApp == nil {
                            runningApp = findRunningApp(withURL: self.url)
                        }
                        if runningApp != nil {
                            self.createObserver(runningApp!)
                        }
                    }
                }
            }
        })
    }

    // Creates an observer (if one doesn't already exist) to watch certain events on each ApplicationEntry.
    func createObserver(_ runningApp: NSRunningApplication) {
        guard observer == nil, let app = Application(runningApp) else {
            return
        }

        observer = app.createObserver(createListener(runningApp))
        do {
            try observer?.addNotification(.applicationDeactivated, forElement: app)
        } catch {
            print("Failed to add observers to [\(app)]: \(error)")
        }
    }

    // The listener that receives the events of the given application. Wraps an instance of an
    // NSRunningApplication so we can use its methods.
    func createListener(_ runningApp: NSRunningApplication) -> (Observer, UIElement, AXNotification) -> () {
        return { (observer, element, event) in
            print("received events for \(runningApp.localizedName!)")
            if runningApp.isTerminated {
                self.observer = nil
                return
            }
            if event == .applicationDeactivated {
                runningApp.hide()
            }
        }
    }

    var asJSON: JSON {
        let shortcut = shortcutCell.shortcutValue!
        let json: JSON = [
            "url": url.absoluteString,
            "name": name,
            "keyCode": shortcut.keyCode,
            "modifierFlags": shortcut.modifierFlags
        ]
        return json
    }

    // The character "." cannot appear in the MASShortcutView.associatedUserDefaultsKey property.
    // See: https://github.com/shpakovski/MASShortcut/issues/64
    static func createApplicationEntryKey(_ url: URL) -> String {
        return "Shortcut::\(url.absoluteString)".replacingOccurrences(of: ".", with: "_")
    }

    // Restore Application entry list from disk.
    static func loadFromDisk(_ entries: inout [ApplicationEntry]) {
        do {
            let jsonString = try String(contentsOf: entrySavePath, encoding: .utf8)
            if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
                let json = try JSON(data: dataFromString)
                for (_, entryJson):(String, JSON) in json {
                    if let appEntry = try ApplicationEntry.init(json: entryJson) {
                        entries.append(appEntry)
                    }
                }
            }
        } catch {
            // Ignore error when there's no file.
            let err = error as NSError
            if err.domain != NSCocoaErrorDomain && err.code != CocoaError.fileReadNoSuchFile.rawValue {
                print("Unexpected error loading application list from disk: \(error)")
            }
        }
    }

    // Save the application entry list to disk.
    static func saveToDisk(_ entries: [ApplicationEntry]) {
        let json = JSON(entries.map { $0.asJSON })
        do {
            if let jsonString = json.rawString() {
                try jsonString.write(to: entrySavePath, atomically: false, encoding: .utf8)
            }
        } catch {
            print("Unexpected error saving application list from disk: \(error)")
        }
    }

    public var debugDescription: String {
        return "AppEntry: \(name), Shortcut: \(shortcutCell.shortcutValue!)"
    }
}

// Launches the application at the given url. First tries to launch it as if it were a an
// application bundle, and if that fails, it tries to run it as if it were an executable.
func launchApplication(at url: URL) -> NSRunningApplication? {
    do {
        return try NSWorkspace.shared.launchApplication(at: url, options: [], configuration: [:])
    } catch {
        DispatchQueue.global(qos: .background).async {
            do {
                // Process.run() is a catchable form of Process.launch() but is only available on
                // macOS 10.13 or later. On macOS 10.12 and below we have to launch the executable
                // with "/usr/bin/env" instead, so it doesn't create a runtime exception and crash
                // the app.
                let process = Process()
                if #available(OSX 10.13, *) {
                    process.executableURL = url
                    try process.run()
                } else {
                    process.launchPath = "/usr/bin/env"
                    process.arguments = [url.path]
                    process.launch()
                }
            } catch {
                print("Could not launch application at \(url), \(error)")
            }
        }
    }

    return nil
}

// Find the running app at the given URL.
func findRunningApp(withURL url: URL) -> NSRunningApplication? {
    let runningApps = NSWorkspace.shared.runningApplications
    if let i = runningApps.index(where: { $0.bundleURL?.path == url.path || $0.executableURL?.path == url.path }) {
        return runningApps[i]
    }
    
    return nil
}
