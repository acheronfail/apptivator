//
//  Configuration.swift
//  Apptivator
//

import SwiftyJSON
import LaunchAtLogin

@objcMembers class ApplicationState: NSObject {
    // Location of our serialised application state.
    let savePath = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(appName)/configuration.json")

    // The list of application -> shortcut mappings.
    var entries: [ApplicationEntry] = []
    // Whether or not the app is globally enabled.
    var appIsEnabled = true
    // Toggle for dark mode.
    var darkModeEnabled = false
    // Don't fire any shortcuts if user is recording a new shortcut.
    var currentlyRecording = false
    // Whether or not the app should launch after login.
    var launchAppAtLogin = LaunchAtLogin.isEnabled

    func isEnabled() -> Bool {
        return appIsEnabled && !currentlyRecording
    }

    // Loads the app state (JSON) from disk - if the file exists, otherwise it does nothing.
    func loadFromDisk() {
        do {
            let jsonString = try String(contentsOf: savePath, encoding: .utf8)
            if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
                let json = try JSON(data: dataFromString)
                for (key, value):(String, JSON) in json {
                    switch key {
                    case "darkModeEnabled":
                        darkModeEnabled = value.bool ?? false
                    case "appIsEnabled":
                        appIsEnabled = value.bool ?? true
                    case "entries":
                        entries = ApplicationEntry.deserialiseList(fromJSON: value)
                    default:
                        print("unknown key '\(key)' encountered in json")
                    }
                }
            }
        } catch {
            // Ignore error when there's no file.
            let err = error as NSError
            if err.domain != NSCocoaErrorDomain && err.code != CocoaError.fileReadNoSuchFile.rawValue {
                print("Unexpected error loading application state from disk: \(error)")
            }
        }
    }

    // Saves the app state to disk, creating the parent directories if they don't already exist.
    func saveToDisk() {
        let json: JSON = [
            "appIsEnabled": appIsEnabled,
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
}
