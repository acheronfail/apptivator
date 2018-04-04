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

    // Include a deinit block during development to ensure that these objects are cleaned up.
    #if DEBUG
    deinit {
        print("\(self.name) entry deinitialised")
    }
    #endif

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

        self.shortcutCell.shortcutValueChange = { [unowned self] (view: MASShortcutView?) in
            MASShortcutBinder.shared().bindShortcut(withDefaultsKey: self.key, toAction: self.apptivate)
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

    // Where the magic happens!
    func apptivate() {
        if self.enabled() {
            if let runningApp = findRunningApp(withURL: self.url) {
                if !runningApp.isActive {
                    if state.showOnScreenWithMouse { self.showOnScreenWithMouse(runningApp) }
                    if runningApp.isHidden { runningApp.unhide() }
                    runningApp.activate(options: .activateIgnoringOtherApps)
                    self.createObserver(runningApp)
                } else if state.hideAppsWithShortcutWhenActive {
                    runningApp.hide()
                }
            } else if state.launchAppIfNotRunning {
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
        return { (observer, element, event) in
            // Remove observer if the app is terminated.
            if runningApp.isTerminated {
                self.observer = nil
                return
            }

            // If enabled, respond to events.
            if self.enabled() && (event == .applicationDeactivated && state.hideAppsWhenDeactivated) {
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
                if let entry = try ApplicationEntry.init(json: entryJson) { entries.append(entry) }
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

// Returns the screen which contains the mouse cursor.
func getScreenWithMouse() -> NSScreen? {
    return NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
}

// Returns the screen that contains the given rect.
func getScreenOfRect(_ rect: CGRect) -> NSScreen? {
    return NSScreen.screens.first { screen in
        var normalised = rect
        normaliseCoordinates(ofRect: &normalised, inScreenFrame: screen.frame)
        return screen.frame.contains(normalised)
    }
}

// Translates a CGRect from one parent rect to another. This is used so when we move a window
// from one screen to another, its ratio and size are proportional to the screen.
func translate(rect: inout CGRect, fromScreenFrame source: CGRect, toScreenFrame dest: CGRect) {
    let xRel = dest.width / source.width
    let yRel = dest.height / source.height

    let xDiff = dest.origin.x - source.origin.x
    let yDiff = dest.origin.y - source.origin.y

    rect.origin.x = (rect.origin.x + xDiff) * xRel
    rect.origin.y = (rect.origin.y + yDiff) * yRel

    rect.size.width *= xRel
    rect.size.height *= yRel
}

// Clamps the given (inner) rect to the outer rect, basically the inner rect may not be larger
// than the outer rect.
func clamp(rect inner: inout CGRect, to outer: CGRect) {
    if (inner.origin.x < outer.origin.x) {
        inner.origin.x = outer.origin.x;
    } else if ((inner.origin.x + inner.size.width) > (outer.origin.x + outer.size.width)) {
        inner.origin.x = outer.origin.x + outer.size.width - inner.size.width;
    }

    if (inner.origin.y < outer.origin.y) {
        inner.origin.y = outer.origin.y;
    } else if ((inner.origin.y + inner.size.height) > (outer.origin.y + outer.size.height)) {
        inner.origin.y = outer.origin.y + outer.size.height - inner.size.height;
    }
}

func normaliseCoordinates(ofRect rect: inout CGRect, inScreenFrame frameOfScreen: CGRect) {
    let frameOfScreenWithMenuBar = NSScreen.screens[0].frame
    rect.origin.y = frameOfScreen.size.height - NSMaxY(rect) + (frameOfScreenWithMenuBar.size.height - frameOfScreen.size.height)
}

// Sets the rect of the given element. The "frame" attribute isn't writable, so we have to
// use the "position" and "size" attributes instead.
func setRect(ofElement element: UIElement, rect: CGRect) {
    do {
        try element.setAttribute(.position, value: rect.origin)
        try element.setAttribute(.size, value: rect.size)
    } catch {
        print("Failed to set frame of UIElement: \(element), \(error)")
    }
}
