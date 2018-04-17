//
//  Configuration.swift
//  Apptivator
//

import SwiftyJSON
import MASShortcut
import LaunchAtLogin

@objcMembers class ApplicationState: NSObject {
    // Location of our serialised application state.
    let savePath: URL

    // User defaults - we use it to provide some experimental overrides that haven't made their way
    // into the UI, but are being considered.
    let defaults: UserDefaults = UserDefaults.standard
    // A Timer to handle the delay between keypresses in a sequence. When this runs out, then the
    // sequence cancels and the user will have to start the sequence from the beginning.
    var timer: Timer?
    // Easier access to the shared instance of MASShortcutMonitor.
    var monitor: MASShortcutMonitor! = MASShortcutMonitor.shared()

    // The list of application -> shortcut mappings.
    var entries: [ApplicationEntry] = []
    // Toggle for dark mode.
    var darkModeEnabled = appleInterfaceStyleIsDark()
    // Whether or not the app should launch after login.
    private var launchAppAtLogin = LaunchAtLogin.isEnabled
    // Don't fire any shortcuts if user is recording a new shortcut.
    private var currentlyRecording = false

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
            "sequentialShortcutDelay": 0.5,
            "matchAppleInterfaceStyle": false,
            "showPopoverOnScreenWithMouse": false
        ])

        // Allow more shortcuts than normal.
        // NOTE: allowing *even more* shortcuts would require a change to the MASShortcut Framework.
        MASShortcutValidator.shared().allowAnyShortcutWithOptionModifier = true
    }

    // Disable all shortcuts when the user is recording a shortcut.
    func onRecordingChange<Value>(_ view: MASShortcutView, _ change: NSKeyValueObservedChange<Value>) {
        currentlyRecording = view.isRecording
    }

    // This resets the shortcut state to its initial setting. This should be called whenever a
    // an ApplicationEntry updates its sequence.
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

    // Only register the shortcuts that are expected. Ideally this should be a private function, but
    // we need to expose it here s in order to write tests for its behaviour.
    func registerShortcuts(atIndex index: Int, last: (UInt, UInt)?) {
        self.unregisterShortcuts()

        // Bind new shortcuts.
        self.entries.forEach({ entry in
            if index < entry.sequence.count {
                let shortcut = entry.sequence[index].shortcutValue!
                // If this is the first shortcut (index == 0) then bind all the first shortcut keys.
                if index == 0 {
                    if !monitor.isShortcutRegistered(shortcut) {
                        monitor.register(shortcut, withAction: { self.keyFired(1, entry, shortcut) })
                    }
                    return
                }

                // If this is a sequential shortcut (index > 0), then only bind the next shortcuts
                // at the given index, whose previous shortcut was hit.
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

    // This is called when a key is hit in a sequence of shortcuts. If it's the last shortcut, it
    // will activate the app, otherwise it will just advance the sequence along.
    private func keyFired(_ i: Int, _ entry: ApplicationEntry, _ shortcut: MASShortcut) {
        if self.currentlyRecording { return }
        if i > 0 { self.timer?.invalidate() }

        // Last shortcut in sequence: apptivate and reset shortcut state.
        if i == entry.sequence.count {
            entry.apptivate()
            self.registerShortcuts(atIndex: 0, last: nil)
        } else {
            // Advance shortcut state with last shortcut and the number of shortcuts hit.
            let last = (shortcut.keyCode, shortcut.modifierFlags)
            self.registerShortcuts(atIndex: i, last: last)
        }
    }

    // This checks the given sequences to see if it conflicts with another sequence. Shortcut
    // sequences must have unique prefixes, so that each one can be distinguished from another.
    // See `SequenceViewController.showConflictingEntry()`.
    func checkForConflictingSequence(_ otherSequence: [MASShortcutView], excluding otherEntry: ApplicationEntry?) -> ApplicationEntry? {
        // It doesn't make sense to call this function with an empty sequence.
        assert(otherSequence.count > 0, "tried to check sequence with count == 0")

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
