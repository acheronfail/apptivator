//
//  Util.swift
//  Apptivator
//

let APPLE_INTERFACE_STYLE = "AppleInterfaceStyle"

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

func appleInterfaceStyleIsDark() -> Bool {
    return UserDefaults.standard.string(forKey: APPLE_INTERFACE_STYLE) == "Dark"
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
