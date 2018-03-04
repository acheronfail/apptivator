//
//  AppDelegate.swift
//  MenuBarApp
//

// Whether or not the app is enabled.
var appIsEnabled = true

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    // Shortcuts window.
    @IBOutlet weak var window: NSWindow!

    var menuBarItem: NSStatusItem? = nil
    var contextMenu: NSMenu = NSMenu()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBarItem?.title = "enabled"
        menuBarItem?.action = #selector(onMenuClick)
        menuBarItem?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(about), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Shortcuts", action: #selector(shortcuts), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitApplication), keyEquivalent: ""))

        #if DEBUG
            shortcuts()
        #endif
    }

    func enable(_ flag: Bool) {
        appIsEnabled = flag
        menuBarItem?.title = flag ? "enabled" : "disabled"
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == .leftMouseUp {
            enable(!appIsEnabled)
        }
    }

    @objc func about() {
        NSApp.orderFrontStandardAboutPanel()
    }

    @objc func shortcuts() {
        window.center()
        window.makeKeyAndOrderFront(window)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Code to tear down application
    }
}

