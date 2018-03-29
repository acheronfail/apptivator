//
//  ApplicationEntry.swift
//  Apptivator
//

import AXSwift
import SwiftyJSON
import MASShortcut

// Amount of time (in seconds) to wait after launching an applicaton until attempting
// to attach listeners to it.
let APP_LAUNCH_DELAY = 2.0

// Represents an item in the Shortcut table of the app's window.
// Each ApplicationEntry is simply a URL of an app mapped to a shortcut.
class ApplicationEntry: CustomDebugStringConvertible {
    let name: String
    let key: String
    let icon: NSImage
    let url: URL
    let shortcutCell: MASShortcutView!
    weak var observer: Observer?
    private var recordingWatcher: NSKeyValueObservation

    init?(url: URL) {
        self.url = url

        // The character "." cannot appear in the MASShortcutView.associatedUserDefaultsKey property.
        // See: https://github.com/shpakovski/MASShortcut/issues/64
        let key = "Shortcut::\(url.absoluteString)".replacingOccurrences(of: ".", with: "_")
        self.key = key
        self.shortcutCell = MASShortcutView()
        self.shortcutCell.associatedUserDefaultsKey = key
        // Watch MASShortcutView.isRecording for changes.
        self.recordingWatcher = self.shortcutCell.observe(\.isRecording) { shortcutCell, _ in
            state.currentlyRecording = shortcutCell.isRecording
        }

        do {
            let properties = try (url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
            self.name = properties[.localizedNameKey] as? String ?? ""
            self.icon = properties[.effectiveIconKey] as? NSImage ?? NSImage()
        } catch {
            return nil
        }

        self.shortcutCell.shortcutValueChange = { [weak self] (view: MASShortcutView?) in
            self?.onShortcutValueChange()
        }
        if let app = findRunningApp(withURL: url) {
            self.createObserver(app)
        }
    }

    convenience init?(json: JSON) throws {
        guard let url = json["url"].url else {
            return nil
        }

        self.init(url: url)
        if let keyCode = json["keyCode"].uInt, let modifierFlags = json["modifierFlags"].uInt {
            let shortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            self.shortcutCell.shortcutValue = shortcut
        }
    }

    func enabled() -> Bool {
        return state.isEnabled() && UIElement.isProcessTrusted(withPrompt: true)
    }

    func onShortcutValueChange() -> () {
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: self.key, toAction: {
            if self.enabled() {
                if let app = findRunningApp(withURL: self.url) {
                    if !app.isActive {
                        if app.isHidden {
                            app.unhide()
                        }
                        app.activate(options: .activateIgnoringOtherApps)
                        self.createObserver(app)
                    } else if state.hideAppsWithShortcutWhenActive {
                        app.hide()
                    }
                } else if state.launchAppIfNotRunning {
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

    // The listener that receives the events of the given application. Wraps an instance of an
    // NSRunningApplication so we can use its methods.
    func createListener(_ runningApp: NSRunningApplication) -> (Observer, UIElement, AXNotification) -> () {
        return { (observer, element, event) in
            // Remove observer if the app is terminated.
            if runningApp.isTerminated {
                self.observer = nil
                return
            }

            // If enabled, respond to events.
            if self.enabled() {
                if event == .applicationDeactivated && state.hideAppsWhenDeactivated {
                    runningApp.hide()
                }
            }
        }
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

    var asJSON: JSON {
        var json: JSON = ["url": url.absoluteString]
        if let shortcut = shortcutCell.shortcutValue {
            json["keyCode"].uInt = shortcut.keyCode
            json["modifierFlags"].uInt = shortcut.modifierFlags
        }
        return json
    }

    static func serialiseList(entries: [ApplicationEntry]) -> JSON {
        return JSON(entries.map { $0.asJSON })
    }

    static func deserialiseList(fromJSON json: JSON) -> [ApplicationEntry] {
        var entries: [ApplicationEntry] = []
        for (_, entryJson):(String, JSON) in json {
            do {
                if let entry = try ApplicationEntry.init(json: entryJson) {
                    entries.append(entry)
                }
            } catch {
                print("Unexpected error deserialising ApplicationEntry: \(entryJson), \(error)")
            }
        }

        return entries
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
                print("Could not launch application at \(url)\n\(error)\n")
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
