//
//  ApplicationEntry.swift
//  Apptivator
//

import SwiftyJSON
import MASShortcut

struct ApplicationEntry: CustomDebugStringConvertible {
    let name: String
    let key: String
    let icon: NSImage
    let url: URL
    var shortcutCell: MASShortcutView
    
    init(url: URL, name: String, icon: NSImage, shortcut: MASShortcut) {
        self.name = name
        self.icon = icon
        self.url = url
        self.shortcutCell = MASShortcutView()
        
        // "." cannot appear here, see: https://github.com/shpakovski/MASShortcut/issues/64
        self.key = makeApplicationEntryKey(url)
        self.shortcutCell.associatedUserDefaultsKey = self.key
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
        return name + " " + "Shortcut: \(shortcutCell.shortcutValue)"
    }
}

// Restore Application list from disk.
func loadItemsFromDisk(_ items: inout [ApplicationEntry]) {
    do {
        let jsonString = try String(contentsOf: entrySavePath, encoding: .utf8)
        let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false)!
        let json = try JSON(data: dataFromString)
        for (_, entryJson):(String, JSON) in json {
            let appEntry = try ApplicationEntry.init(json: entryJson)!
            items.append(appEntry)
        }
    } catch {
        print("oops - couldn't load list from file")
    }
}

func saveItemsToDisk(_ items: [ApplicationEntry]) {
    // Save item list to disk.
    let json = JSON(items.map { $0.asJSON })
    do {
        try json.rawString()?.write(to: entrySavePath, atomically: false, encoding: .utf8)
    } catch {
        print("oops! couldn't save list!")
    }
}

func makeApplicationEntryKey(_ url: URL) -> String {
    return "Shortcut::\(url.absoluteString)".replacingOccurrences(of: ".", with: "_")
}

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
                }
            }
        })
    }
}

func findApp(withURL url: URL) -> NSRunningApplication? {
    let runningApps = NSWorkspace.shared.runningApplications
    if let i = runningApps.index(where: { $0.bundleURL?.path == url.path || $0.executableURL?.path == url.path }) {
        return runningApps[i]
    }
    
    return nil
}
