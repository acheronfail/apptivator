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

struct ApplicationConfig: Equatable {
    // When the app is active, should pressing the shortcut hide it?
    var hideWithShortcutWhenActive: Bool = true
    // When activating, move windows to the screen where the mouse is.
    var showOnScreenWithMouse: Bool = false
    // Should the app be automatically hidden once it loses focus?
    var hideWhenDeactivated: Bool = false
    // Should we launch the application if it's not running and the shortcut is pressed?
    var launchIfNotRunning: Bool = false

    // Allow this struct to be subscripted. Swift makes this overly verbose. T_T
    subscript(_ key: String) -> Bool? {
        get {
            if key == "hideWithShortcutWhenActive" { return self.hideWithShortcutWhenActive }
            if key == "showOnScreenWithMouse" { return self.showOnScreenWithMouse }
            if key == "hideWhenDeactivated" { return self.hideWhenDeactivated }
            if key == "launchIfNotRunning" { return self.launchIfNotRunning }
            return nil
        }
        set {
            if newValue != nil {
                if key == "hideWithShortcutWhenActive" { self.hideWithShortcutWhenActive = newValue! }
                if key == "showOnScreenWithMouse" { self.showOnScreenWithMouse = newValue! }
                if key == "hideWhenDeactivated" { self.hideWhenDeactivated = newValue! }
                if key == "launchIfNotRunning" { self.launchIfNotRunning = newValue! }
            }
        }
    }

    init(withValues: [String: Bool]?) {
        if let opts = withValues {
            hideWithShortcutWhenActive = opts["hideWithShortcutWhenActive"] ?? hideWithShortcutWhenActive
            showOnScreenWithMouse = opts["showOnScreenWithMouse"] ?? showOnScreenWithMouse
            hideWhenDeactivated = opts["hideWhenDeactivated"] ?? hideWhenDeactivated
            launchIfNotRunning = opts["launchIfNotRunning"] ?? launchIfNotRunning
        }
    }

    var asJSON: JSON {
        let json: JSON = [
            "hideWithShortcutWhenActive": hideWithShortcutWhenActive,
            "showOnScreenWithMouse": showOnScreenWithMouse,
            "hideWhenDeactivated": hideWhenDeactivated,
            "launchIfNotRunning": launchIfNotRunning
        ]
        return json
    }
}

// Represents an item in the Shortcut table of the app's window.
// Each ApplicationEntry is simply a URL of an app mapped to a shortcut.
class ApplicationEntry: CustomDebugStringConvertible {
    let url: URL
    let key: String
    let name: String
    let icon: NSImage
    let shortcutView: MASShortcutView!

    var config: ApplicationConfig
    private var observer: Observer?
    private var changeWatcher: NSKeyValueObservation!
    private var recordingWatcher: NSKeyValueObservation!

    var isActive: Bool {
        return self.observer != nil
    }

    var isEnabled: Bool {
        return state.isEnabled && UIElement.isProcessTrusted(withPrompt: true)
    }

    init?(url: URL, config: [String:Bool]?) {
        self.url = url
        self.config = ApplicationConfig(withValues: config)

        let key = ApplicationEntry.generateKey(for: url)
        self.key = key
        self.shortcutView = MASShortcutView()
        self.recordingWatcher = self.shortcutView.observe(\.isRecording, changeHandler: state.onRecordingChange)

        do {
            let properties = try (url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
            self.name = properties[.localizedNameKey] as? String ?? ""
            self.icon = properties[.effectiveIconKey] as? NSImage ?? NSImage()
        } catch {
            return nil
        }

        self.changeWatcher = self.shortcutView.observe(\.shortcutValue, options: [.prior]) { [unowned self] shortcutView, x in
            if let shortcut = shortcutView.shortcutValue {
                if x.isPrior {
                    MASShortcutMonitor.shared().unregisterShortcut(shortcut)
                } else {
                    MASShortcutMonitor.shared().register(shortcut, withAction: self.apptivate)
                }
            }
        }

        if let app = findRunningApp(withURL: url) {
            self.createObserver(app)
        }
    }

    convenience init?(json: JSON) throws {
        guard let url = json["url"].url else {
            return nil
        }

        self.init(url: url, config: json["config"].dictionaryObject as? [String:Bool] ?? nil)
        if let keyCode = json["keyCode"].uInt, let modifierFlags = json["modifierFlags"].uInt {
            let shortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            self.shortcutView.shortcutValue = shortcut
        }
    }

    // MASShortcutMonitor holds on to a reference to `self.shortcutView.shortcutValue`, so it won't
    // be automatically released when it goes out of scope. In order for it to be released we need
    // to make sure this reference is removed.
    func unregister() {
        if let shortcut = self.shortcutView.shortcutValue {
            MASShortcutMonitor.shared().unregisterShortcut(shortcut)
        }
    }

    // Where the magic happens!
    func apptivate() {
        if self.isEnabled {
            if let runningApp = findRunningApp(withURL: self.url) {
                if !runningApp.isActive {
                    if self.config.showOnScreenWithMouse { self.showOnScreenWithMouse(runningApp) }
                    if runningApp.isHidden { runningApp.unhide() }
                    runningApp.activate(options: .activateIgnoringOtherApps)
                    self.createObserver(runningApp)
                } else if self.config.hideWithShortcutWhenActive {
                    runningApp.hide()
                }
            } else if self.config.launchIfNotRunning {
                // Launch the application if it's not running, and after a delay attempt to
                // create an observer to watch it for events. We have to wait since we cannot
                // start observing an application if it hasn't fully launched.
                // TODO: there's probably a better way of doing this.
                var runningApp = launchApplication(at: self.url)
                DispatchQueue.main.asyncAfter(deadline: .now() + APP_LAUNCH_DELAY) {
                    if runningApp == nil { runningApp = findRunningApp(withURL: self.url) }
                    if runningApp != nil { self.createObserver(runningApp!) }
                }
            }
        }
    }

    // Move all the application's windows to the screen where the mouse currently lies.
    func showOnScreenWithMouse(_ runningApp: NSRunningApplication) {
        if let destScreen = getScreenWithMouse(), let app = Application(runningApp) {
            do {
                for window in try app.windows()! {
                    // Get current CGRect of the window.
                    let prevFrame: CGRect = try window.attribute(.frame)!
                    var frame = prevFrame
                    if let screenOfRect = getScreenOfRect(prevFrame) {
                        if screenOfRect == destScreen { continue }
                        // Translate that rect's coords from the source screen to the dest screen.
                        translate(rect: &frame, fromScreenFrame: screenOfRect.frame, toScreenFrame: destScreen.frame)
                        // Clamp the rect's values inside the visible frame of the dest screen.
                        clamp(rect: &frame, to: destScreen.visibleFrame)
                        // Ensure rect's coords are valid.
                        normaliseCoordinates(ofRect: &frame, inScreenFrame: destScreen.frame)
                        // Move the window to the new destination.
                        if !frame.equalTo(prevFrame) { setRect(ofElement: window, rect: frame) }
                    } else {
                        print("Failed to find screen of rect: \(prevFrame)")
                    }
                }
            } catch {
                print("Failed to move windows of \(app) (\(runningApp))")
            }
        }
    }

    // The listener that receives the events of the given application. Wraps an instance of an
    // NSRunningApplication so we can use its methods.
    func createListener(_ runningApp: NSRunningApplication) -> (Observer, UIElement, AXNotification) -> () {
        return { [unowned self] (observer, element, event) in
            // Remove observer if the app is terminated.
            if runningApp.isTerminated {
                self.observer = nil
                return
            }

            // If enabled, respond to events.
            if self.isEnabled && (event == .applicationDeactivated && self.config.hideWhenDeactivated) {
                runningApp.hide()
            }
        }
    }

    // Creates an observer (if one doesn't already exist) to watch certain events on each ApplicationEntry.
    func createObserver(_ runningApp: NSRunningApplication) {
        guard observer == nil, let app = Application(runningApp) else { return }

        observer = app.createObserver(createListener(runningApp))
        do {
            try observer?.addNotification(.applicationDeactivated, forElement: app)
        } catch {
            print("Failed to add observers to [\(app)]: \(error)")
        }
    }

    var shortcutAsString: String {
        let shortcutSequence = [self.shortcutView.shortcutValue]
        let str = shortcutSequence.compactMap({ $0 != nil ? "\($0!)" : nil }).joined(separator: ", ")
        return str.count > 0 ? str : "nil"
    }

    var asJSON: JSON {
        var json: JSON = [
            "url": url.absoluteString,
            "config": self.config.asJSON
        ]
        if let shortcut = shortcutView.shortcutValue {
            json["keyCode"].uInt = shortcut.keyCode
            json["modifierFlags"].uInt = shortcut.modifierFlags
        }
        return json
    }

    public var debugDescription: String {
        return "AppEntry: { \(name), Shortcut: \(String(describing: shortcutView.shortcutValue)) }"
    }

    // The characters "." and " " cannot appear in the MASShortcutView.associatedUserDefaultsKey
    // property. See: https://github.com/shpakovski/MASShortcut/issues/64
    // and https://github.com/shpakovski/MASShortcut/blob/master/Framework/MASShortcutBinder.m#L44-L47
    static func generateKey(for url: URL) -> String {
        return "Shortcut::\(url.absoluteString)"
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func serialiseList(entries: [ApplicationEntry]) -> JSON {
        return JSON(entries.map { $0.asJSON })
    }

    static func deserialiseList(fromJSON json: JSON) -> [ApplicationEntry] {
        var entries: [ApplicationEntry] = []
        for (_, entryJson):(String, JSON) in json {
            do {
                if let entry = try ApplicationEntry.init(json: entryJson) { entries.append(entry) }
            } catch {
                print("Unexpected error deserialising ApplicationEntry: \(entryJson), \(error)")
            }
        }

        return entries
    }
}
