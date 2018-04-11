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
