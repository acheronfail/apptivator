//
//  Configuration.swift
//  Apptivator
//

import SwiftyJSON
import LaunchAtLogin

@objcMembers class ApplicationState: NSObject {
    // Location of our serialised application state.
    let savePath: URL

    // User defaults - we use it to provide some experimental overrides that haven't made their way
    // into the UI, but are being considered.
    let defaults: UserDefaults = UserDefaults.standard
    // TODO: doc
    var timer: Timer?
    // TODO: doc
    var monitor: MASShortcutMonitor! = MASShortcutMonitor.shared()

    // The list of application -> shortcut mappings.
    var entries: [ApplicationEntry] = []
    // Toggle for dark mode.
    var darkModeEnabled = appleInterfaceStyleIsDark()
    // Don't fire any shortcuts if user is recording a new shortcut.
    private var currentlyRecording = false
    // Whether or not the app should launch after login.
    private var launchAppAtLogin = LaunchAtLogin.isEnabled

    // Whether or not the app is globally enabled.
    private var _isEnabled = true
    var isEnabled: Bool {
        get { return _isEnabled && !currentlyRecording }
        set { _isEnabled = newValue }
    }

    init(atPath url: URL) {
        self.savePath = url

        defaults.register(defaults: [
            "leftClickToggles": false,
            // TODO: add to about
            "sequentialShortcutDelay": 0.5,
            "matchAppleInterfaceStyle": false,
            "showPopoverOnScreenWithMouse": false
        ])

        // TODO: add option in for this?
        MASShortcutValidator.shared().allowAnyShortcutWithOptionModifier = true
    }

    // TODO: doc
    private func keyFired(_ i: Int, _ entry: ApplicationEntry, _ shortcut: MASShortcut) {
        if self.currentlyRecording { return }
        if i > 0 { self.timer?.invalidate() }

        // TODO: to stop this being hit at the wrong time, maybe sequences shouldn't contain
        // subsets of other sequences..?
        // TODO: if this is hit, then we should return early
        // TODO: see self.isSequenceRegistered
        if i == entry.sequence.count {
            entry.apptivate()
            self.registerShortcuts(atIndex: 0, last: nil)
        } else {
            let last = (shortcut.keyCode, shortcut.modifierFlags)
            self.registerShortcuts(atIndex: i, last: last)
        }
    }

    // TODO: doc
    // Should be called whenever a shortcut changes value
    func registerShortcuts() {
        self.registerShortcuts(atIndex: 0, last: nil)
    }

    // Unregister all previously registered application shortcuts. We can't just use
    // monitor.unregisterAllShortcuts() since that unregisters *all* bindings (even those bound
    // with MASShortcutBinder).
    func unregisterShortcuts() {
        self.entries.forEach({ entry in
            entry.sequence.forEach({ shortcutView in
                if monitor.isShortcutRegistered(shortcutView.shortcutValue) {
                    monitor.unregisterShortcut(shortcutView.shortcutValue)
                }
            })
        })
    }

    // TODO: doc
    // TODO: doc - probably shouldn't be called, but need it for tests
    func registerShortcuts(atIndex index: Int, last: (UInt, UInt)?) {
        self.unregisterShortcuts()

        // Bind new shortcuts.
        self.entries.forEach({ entry in
            if index < entry.sequence.count {
                let shortcut = entry.sequence[index].shortcutValue!
                // If this is the first shortcut (index = 0), then bind all the first shortcut keys.
                if index == 0 {
                    if !monitor.isShortcutRegistered(shortcut) {
                        monitor.register(shortcut, withAction: { self.keyFired(1, entry, shortcut) })
                    }
                    return
                }

                // If this is a sequential shortcut (index > 0), then only bind the next shortcuts
                // whose previous shortcut was hit.
                let (lastKeyCode, lastModifierFlags) = last!
                let prev = entry.sequence[index - 1].shortcutValue!
                if prev.keyCode == lastKeyCode && prev.modifierFlags == lastModifierFlags {
                    if !monitor.isShortcutRegistered(shortcut) {
                        monitor.register(shortcut, withAction: { self.keyFired(index + 1, entry, shortcut) })
                    }
                }
            }
        })

        // If this is a sequential shortcut, then start a timer to reset back to the initial state
        // if no other shortcuts were hit.
        if index > 0 {
            let interval = TimeInterval(defaults.float(forKey: "sequentialShortcutDelay"))
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                self.timer = nil
                self.registerShortcuts(atIndex: 0, last: nil)
            }
        }
    }

    // TODO: this
    func checkForConflictingSequence(_ otherSequence: [MASShortcutView], excluding otherEntry: ApplicationEntry?) -> ApplicationEntry? {
        if otherSequence.count == 0 { return nil }
        return self.entries.first(where: { entry in
            if entry.sequence.count == 0 || entry === otherEntry { return false }
            var wasConflict = true
            for (a, b) in zip(otherSequence, entry.sequence) {
                if a.shortcutValue != b.shortcutValue {
                    wasConflict = false
                    break
                }
            }

            return wasConflict
        })
    }

    func onRecordingChange<Value>(_ view: MASShortcutView, _ change: NSKeyValueObservedChange<Value>) {
        currentlyRecording = view.isRecording
    }

    // Loads the app state (JSON) from disk - if the file exists, otherwise it does nothing.
    func loadFromDisk() {
        do {
            let jsonString = try String(contentsOf: savePath, encoding: .utf8)
            try loadFromString(jsonString)
        } catch {
            // Ignore error when there's no file.
            let err = error as NSError
            if err.domain != NSCocoaErrorDomain && err.code != CocoaError.fileReadNoSuchFile.rawValue {
                print("Unexpected error loading application state from disk: \(error)")
            }
        }

        registerShortcuts()
    }

    func loadFromString(_ jsonString: String) throws {
        if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
            let json = try JSON(data: dataFromString)
            for (key, value):(String, JSON) in json {
                switch key {
                case "darkModeEnabled":
                    darkModeEnabled = value.bool ?? false
                case "appIsEnabled":
                    _isEnabled = value.bool ?? true
                case "entries":
                    entries = ApplicationEntry.deserialiseList(fromJSON: value)
                default:
                    print("unknown key '\(key)' encountered in json")
                }
            }

            if state.defaults.bool(forKey: "matchAppleInterfaceStyle") {
                darkModeEnabled = appleInterfaceStyleIsDark()
            }
        }
    }

    // Saves the app state to disk, creating the parent directories if they don't already exist.
    func saveToDisk() {
        let json: JSON = [
            "appIsEnabled": _isEnabled,
            "darkModeEnabled": darkModeEnabled,
            "entries": ApplicationEntry.serialiseList(entries: entries)
        ]
        do {
            if let jsonString = json.rawString() {
                let configDir = savePath.deletingLastPathComponent()
                try FileManager.default.createDirectory(atPath: configDir.path, withIntermediateDirectories: true, attributes: nil)
                try jsonString.write(to: savePath, atomically: false, encoding: .utf8)
                print("Saved config to disk")
            } else {
                print("Could not serialise config")
            }
        } catch {
            print("Unexpected error saving application state to disk: \(error)")
        }
    }

    // When running tests, use a temporary config file.
    static func defaultConfigurationPath() -> URL {
        if ProcessInfo.processInfo.environment["TEST"] != nil {
            return URL(fileURLWithPath: "\(NSTemporaryDirectory())\(APP_NAME)-\(UUID().uuidString).json")
        }

        return URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(APP_NAME)/configuration.json")
    }
}
