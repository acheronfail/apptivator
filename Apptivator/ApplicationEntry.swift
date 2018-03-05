//
//  ApplicationEntry.swift
//  Apptivator
//

import Cocoa
import AXSwift
import SwiftyJSON
import MASShortcut

// Where the app -> shortcut mappings are stored.
let entrySavePath = URL(fileURLWithPath: "/Users/acheronfail/Desktop/output.json")

// Represents an item in the Shortcut table of the app's window.
// Each ApplicationEntry is simply a URL of an app mapped to a shortcut.
struct ApplicationEntry: CustomDebugStringConvertible {
    let name: String
    let key: String
    let icon: NSImage
    let url: URL
    let shortcutCell: MASShortcutView
    let observer: Observer? = nil
    
    init(url: URL, name: String, icon: NSImage, shortcut: MASShortcut) {
        self.name = name
        self.icon = icon
        self.url = url
        self.shortcutCell = MASShortcutView()
        
        let key = makeApplicationEntryKey(url)
        self.key = key
        self.shortcutCell.associatedUserDefaultsKey = key
        
        self.shortcutCell.shortcutValueChange = makeBinder(forEntry: self)
    }
    
    init?(json: JSON) throws {
        self.url = json["url"].url!
        let properties = try (self.url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
        self.name = properties[.localizedNameKey] as? String ?? json["name"].string ?? ""
        self.icon = properties[.effectiveIconKey] as? NSImage ?? NSImage()
        
        let key = makeApplicationEntryKey(self.url)
        self.key = key
        self.shortcutCell = MASShortcutView()
        self.shortcutCell.associatedUserDefaultsKey = key
        
        self.shortcutCell.shortcutValueChange = makeBinder(forEntry: self)
        let shortcut = MASShortcut(keyCode: json["keyCode"].uInt!, modifierFlags: json["modifierFlags"].uInt!)
        self.shortcutCell.shortcutValue = shortcut
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
    
    public var debugDescription: String {
        return name + " " + "Shortcut: \(shortcutCell.shortcutValue!)"
    }
}

// Restore Application entry list from disk.
func loadEntriesFromDisk(_ entries: inout [ApplicationEntry]) {
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
func saveEntriesToDisk(_ entries: [ApplicationEntry]) {
    let json = JSON(entries.map { $0.asJSON })
    do {
        if let jsonString = json.rawString() {
            try jsonString.write(to: entrySavePath, atomically: false, encoding: .utf8)
        }
    } catch {
        print("Unexpected error saving application list from disk: \(error)")
    }
}

// The character "." cannot appear in the MASShortcutView.associatedUserDefaultsKey property.
// See: https://github.com/shpakovski/MASShortcut/issues/64
func makeApplicationEntryKey(_ url: URL) -> String {
    return "Shortcut::\(url.absoluteString)".replacingOccurrences(of: ".", with: "_")
}

// Initialises an observer to watch certain events on each ApplicationEntry.
func makeObserver(atURL url: URL) -> Observer? {
    return nil
}

// Creates a function that returns a function which updates the global shortcut binding
// each time that it's called.
func makeBinder(forEntry entry: ApplicationEntry) -> (MASShortcutView?) -> () {
    return { sender in
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: entry.key, toAction: {
            if appIsEnabled && UIElement.isProcessTrusted(withPrompt: true) {
                if let app = findApp(withURL: entry.url) {
                    if app.isActive {
                        app.hide()
                    } else {
                        app.activate(options: .activateIgnoringOtherApps)
                    }
                } else {
                    launchApplication(at: entry.url)
                }
            }
        })
    }
}

// Launches the application at the given url. First tries to launch it as if it were a an
// application bundle, and if that fails, it tries to run it as if it were an executable.
func launchApplication(at url: URL) {
    do {
        try NSWorkspace.shared.launchApplication(at: url, options: [], configuration: [:])
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
                    process.waitUntilExit()
                    if process.terminationStatus != 0 {
                        print("An error occurred launching the executable, /usr/bin/env exit status: \(process.terminationStatus)")
                    }
                }
            } catch {
                print("Could not launch \(error)")
            }
        }
    }
}

// Find the app at the given URL.
func findApp(withURL url: URL) -> NSRunningApplication? {
    let runningApps = NSWorkspace.shared.runningApplications
    if let i = runningApps.index(where: { $0.bundleURL?.path == url.path || $0.executableURL?.path == url.path }) {
        return runningApps[i]
    }
    
    return nil
}
