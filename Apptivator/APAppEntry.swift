//
//  APAppEntry.swift
//  Apptivator
//

import Cocoa
import AXSwift
import SwiftyJSON
import MASShortcut
import CleanroomLogger

// Amount of time (in seconds) to wait after launching an applicaton until attempting
// to attach listeners to it.
let APP_LAUNCH_DELAY = 2.0

enum APRunningAppAction {
    case reopen, activate, hide, none
}

struct APAppConfig: Equatable {
    // When the app is active, should pressing the shortcut hide it?
    var hideWithShortcutWhenActive: Bool = true
    // When activating, move windows to the screen where the mouse is.
    var showOnScreenWithMouse: Bool = false
    // Should the app be automatically hidden once it loses focus?
    var hideWhenDeactivated: Bool = false
    // Should we launch the application if it's not running and the shortcut is pressed?
    var launchIfNotRunning: Bool = false

    // Ask the app to reopen when it is running without any windows.
    var reopenWhenNoWindows: Bool = false

    func actionForRunningApp(isActive: Bool, windowCount: Int?) -> APRunningAppAction {
        if reopenWhenNoWindows && windowCount == 0 { return .reopen }
        if !isActive { return .activate }
        return hideWithShortcutWhenActive ? .hide : .none
    }

    // Allow this struct to be subscripted. Swift makes this overly verbose. T_T
    subscript(_ key: String) -> Bool? {
        get {
            if key == "hideWithShortcutWhenActive" { return self.hideWithShortcutWhenActive }
            if key == "showOnScreenWithMouse" { return self.showOnScreenWithMouse }
            if key == "hideWhenDeactivated" { return self.hideWhenDeactivated }
            if key == "launchIfNotRunning" { return self.launchIfNotRunning }
            if key == "reopenWhenNoWindows" { return self.reopenWhenNoWindows }
            return nil
        }
        set {
            if newValue != nil {
                if key == "hideWithShortcutWhenActive" { self.hideWithShortcutWhenActive = newValue! }
                if key == "showOnScreenWithMouse" { self.showOnScreenWithMouse = newValue! }
                if key == "hideWhenDeactivated" { self.hideWhenDeactivated = newValue! }
                if key == "launchIfNotRunning" { self.launchIfNotRunning = newValue! }
                if key == "reopenWhenNoWindows" { self.reopenWhenNoWindows = newValue! }
            }
        }
    }

    init(withValues: [String: Bool]?) {
        if let opts = withValues {
            hideWithShortcutWhenActive = opts["hideWithShortcutWhenActive"] ?? hideWithShortcutWhenActive
            showOnScreenWithMouse = opts["showOnScreenWithMouse"] ?? showOnScreenWithMouse
            hideWhenDeactivated = opts["hideWhenDeactivated"] ?? hideWhenDeactivated
            launchIfNotRunning = opts["launchIfNotRunning"] ?? launchIfNotRunning
            reopenWhenNoWindows = opts["reopenWhenNoWindows"] ?? reopenWhenNoWindows
        }
    }

    var asJSON: JSON {
        let json: JSON = [
            "hideWithShortcutWhenActive": hideWithShortcutWhenActive,
            "showOnScreenWithMouse": showOnScreenWithMouse,
            "hideWhenDeactivated": hideWhenDeactivated,
            "launchIfNotRunning": launchIfNotRunning,
            "reopenWhenNoWindows": reopenWhenNoWindows
        ]
        return json
    }
}

// Represents an item in the Shortcut table of the app's window.
// Each APAppEntry is simply a URL of an app mapped to a shortcut.
class APAppEntry: CustomDebugStringConvertible {
    let url: URL
    let name: String
    let icon: NSImage

    var config: APAppConfig
    private var watcher: NSKeyValueObservation?
    private var observer: Observer?

    var isActive: Bool { return self.observer != nil }
    var isEnabled: Bool { return APState.shared.isEnabled && UIElement.isProcessTrusted(withPrompt: true) }
    var sequence: [MASShortcutView] = [] {
        didSet {
            // Unregister old shortcuts if any of them are registered. `state.registerShortcuts()` will
            // unregister all other shortcuts anyway, so this can be called outside of the state.
            oldValue.forEach({ shortcutView in
                if APState.shared.monitor.isShortcutRegistered(shortcutView.shortcutValue) {
                    APState.shared.monitor.unregisterShortcut(shortcutView.shortcutValue)
                }
            })
        }
    }

    init?(url: URL, config: [String:Bool]?) {
        self.url = url
        self.config = APAppConfig(withValues: config)

        do {
            let properties = try (url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
            self.name = properties[.localizedNameKey] as? String ?? ""
            self.icon = properties[.effectiveIconKey] as? NSImage ?? NSImage()
        } catch {
            return nil
        }

        self.createObserver(findRunningApp(withURL: self.url))
    }

    convenience init?(json: JSON) throws {
        guard let url = json["url"].url else {
            return nil
        }

        self.init(url: url, config: json["config"].dictionaryObject as? [String:Bool] ?? nil)

        var sequence: [MASShortcutView] = []
        for (_, value):(String, JSON) in json["sequence"] {
            if let keyCode = value["keyCode"].int, let modifierFlags = value["modifierFlags"].uInt {
                let shortcutView = MASShortcutView()
                shortcutView.shortcutValue = MASShortcut(keyCode: keyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: modifierFlags))
                sequence.append(shortcutView)
            }
        }
        self.sequence = sequence
    }

    // Where the magic happens!
    func apptivate() {
        if self.isEnabled {
            if let runningApp = findRunningApp(withURL: self.url) {
                let windowCount = self.config.reopenWhenNoWindows ? self.windowCount(runningApp) : nil
                switch self.config.actionForRunningApp(isActive: runningApp.isActive, windowCount: windowCount) {
                case .reopen:
                    self.reopenApplication(runningApp)
                case .activate:
                    if self.config.showOnScreenWithMouse { self.showOnScreenWithMouse(runningApp) }
                    if runningApp.isHidden { runningApp.unhide() }
                    runningApp.activate(options: .activateIgnoringOtherApps)
                    self.createObserver(runningApp)
                case .hide:
                    runningApp.hide()
                case .none:
                    break
                }
            } else if self.config.launchIfNotRunning {
                // Launch the application if it's not running, and after a delay attempt to
                // create an observer to watch it for events. We have to wait since we cannot
                // start observing an application if it hasn't fully launched.
                // TODO: there's probably a better way of doing this.
                let _ = launchApplication(at: self.url)
                DispatchQueue.main.asyncAfter(deadline: .now() + APP_LAUNCH_DELAY) {
                    self.createObserver(findRunningApp(withURL: self.url))
                }
            }
        }
    }

    // AXWindows includes minimized windows. Missing attributes and AX errors are unknown,
    // not evidence that the application has no windows.
    private func windowCount(_ runningApp: NSRunningApplication) -> Int? {
        guard let app = Application(runningApp) else { return nil }
        do {
            return try app.windows()?.count
        } catch {
            Log.warning?.message("Could not inspect windows of \(runningApp): \(error)")
            return nil
        }
    }

    private func reopenApplication(_ runningApp: NSRunningApplication) {
        guard let bundleURL = runningApp.bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    Log.error?.message("Could not reopen application at \(bundleURL): \(error)")
                    return
                }
                self.createObserver(app)
                if self.config.showOnScreenWithMouse, let app = app {
                    self.showOnScreenWithMouse(app)
                }
            }
        }
    }

    // Move all the application's windows to the screen where the mouse currently lies.
    private func showOnScreenWithMouse(_ runningApp: NSRunningApplication) {
        if let destScreen = getScreenWithMouse(), let app = Application(runningApp) {
            do {
                guard let windows = try app.windows() else { return }
                for window in windows {
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
                        Log.error?.message("Failed to find screen of rect: \(prevFrame)")
                    }
                }
            } catch {
                Log.error?.message("Failed to move windows of \(app) (\(runningApp))")
            }
        }
    }

    // The listener that receives the events of the given application. Wraps an instance of an
    // NSRunningApplication so we can use its methods.
    private func createListener(_ runningApp: NSRunningApplication) -> (Observer, UIElement, AXNotification) -> () {
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

    // Creates an observer (if one doesn't already exist) to watch certain events on each entry.
    // Also watches `runningApp.isTerminated` for when the application is quit.
    func createObserver(_ runningApp: NSRunningApplication?) {
        guard observer == nil, runningApp != nil, let app = Application(runningApp!) else { return }

        // Called when the application quits. Cleans up our resources.
        // This is also required so that `self.isActive()` returns an accurate value.
        watcher = runningApp?.observe(\.isTerminated, changeHandler: { [unowned self] _, _ in
            self.observer = nil
            self.watcher = nil
        })

        // Start watching Accessibility API notifications so we know when the application is
        // deactivated.
        observer = app.createObserver(createListener(runningApp!))
        do {
            try observer?.addNotification(.applicationDeactivated, forElement: app)
        } catch {
            Log.error?.message("Failed to add observers to [\(app)]: \(error)")
        }
    }

    var shortcutString: String? {
        let str = sequence
            .compactMap({ $0.shortcutValue?.description })
            .joined(separator: ", ")
        return str.count > 0 ? str : nil
    }

    var asJSON: JSON {
        return [
            "url": url.absoluteString,
            "config": config.asJSON,
            "sequence": sequence.map({ shortcutView in
                var json: JSON = [:]
                if let shortcut = shortcutView.shortcutValue {
                    json["keyCode"].int = shortcut.keyCode
                    json["modifierFlags"].uInt = shortcut.modifierFlags.rawValue
                }
                return json
            }) as [JSON]
        ] as JSON
    }

    public var debugDescription: String {
        return "AppEntry: { \(name), Shortcut: \(shortcutString ?? "nil") }"
    }

    static func serialiseList(entries: ArraySlice<APAppEntry>) -> JSON {
        return JSON(entries.map { $0.asJSON })
    }

    static func deserialiseList(fromJSON json: JSON) -> [APAppEntry] {
        var entries: [APAppEntry] = []
        for (_, entryJson):(String, JSON) in json {
            do {
                if let entry = try APAppEntry.init(json: entryJson) { entries.append(entry) }
            } catch {
                Log.error?.message("Unexpected error deserialising ApplicationEntry: \(entryJson), \(error)")
            }
        }

        return entries
    }
}
