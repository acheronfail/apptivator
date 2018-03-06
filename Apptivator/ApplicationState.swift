//
//  Configuration.swift
//  Apptivator
//

import SwiftyJSON

class ApplicationState: NSObject {
    // Location of our serialised application state.
    let savePath = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(appName)/configuration.json")

    // The list of application -> shortcut mappings.
    var entries: [ApplicationEntry] = []
    // Whether or not the app is globally enabled.
    var appIsEnabled = true
    // Whether or not the app should launch after login.
    var launchAppAtLogin = false
    // Should we launch the application if it's not running and the shortcut is pressed?
    var launchAppIfNotRunning = true
    // Should apps in the list be automatically hidden once they lose focus?
    var hideAppsWhenDeactivated = true
    // When the application is active, should pressing the shortcut hide the app?
    var hideAppsWithShortcutWhenActive = true

    // Loads the app state (JSON) from disk - if the file exists, otherwise it does nothing.
    func loadFromDisk() {
        do {
            let jsonString = try String(contentsOf: savePath, encoding: .utf8)
            if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
                let json = try JSON(data: dataFromString)
                for (key, value):(String, JSON) in json {
                    switch key {
                    case "entries":
                        entries = ApplicationEntry.deserialiseList(fromJSON: value)
                    case "hideAppsWithShortcutWhenActive":
                        hideAppsWithShortcutWhenActive = value.bool ?? hideAppsWithShortcutWhenActive
                    case "hideAppsWhenDeactivated":
                        hideAppsWhenDeactivated = value.bool ?? hideAppsWhenDeactivated
                    case "launchAppIfNotRunning":
                        launchAppIfNotRunning = value.bool ?? launchAppIfNotRunning
                    case "launchAppAtLogin":
                        launchAppAtLogin = value.bool ?? launchAppAtLogin
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
            "entries": ApplicationEntry.serialiseList(entries: entries),
            "hideAppsWithShortcutWhenActive": hideAppsWithShortcutWhenActive,
            "hideAppsWhenDeactivated": hideAppsWhenDeactivated,
            "launchAppIfNotRunning": launchAppIfNotRunning,
            "launchAppAtLogin": launchAppAtLogin
        ]
        do {
            if let jsonString = json.rawString() {
                let configDir = savePath.deletingLastPathComponent()
                try FileManager.default.createDirectory(atPath: configDir.path, withIntermediateDirectories: true, attributes: nil)
                try jsonString.write(to: savePath, atomically: false, encoding: .utf8)
            }
        } catch {
            print("Unexpected error saving application state to disk: \(error)")
        }
    }
}
