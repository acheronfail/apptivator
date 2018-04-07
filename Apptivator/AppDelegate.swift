//
//  AppDelegate.swift
//  Apptivator
//

import SwiftyJSON

// Global application state.
let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
let state = ApplicationState()

// Menu bar item icons.
let iconOn = NSImage(named: NSImage.Name(rawValue: "icon-on"))
let iconOff = NSImage(named: NSImage.Name(rawValue: "icon-off"))

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    // Shortcuts window.
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var viewController: ViewController!

    var menuBarItem: NSStatusItem? = nil
    var contextMenu: NSMenu = NSMenu()
    let enabledIndicator = NSMenuItem(title: "\(appName): Enabled", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupIcon(iconOn)
        setupIcon(iconOff)

        menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBarItem?.image = iconOn
        menuBarItem?.action = #selector(onMenuClick)
        menuBarItem?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        contextMenu.addItem(enabledIndicator)
        contextMenu.addItem(NSMenuItem(title: "Configure Shortcuts", action: #selector(togglePreferencesWindow), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitApplication), keyEquivalent: ""))

        enable(true)
        state.loadFromDisk()
        viewController.reloadView()

        // Check for accessibility permissions.
        if !UIElement.isProcessTrusted(withPrompt: true) {
            let alert = NSAlert()
            alert.messageText = "Action Required"
            alert.informativeText = "\(appName) requires access to the accessibility API in order to hide/show other application's windows.\n\nPlease open System Preferences and allow \(appName) access.\n\nSystem Preferences -> Security & Privacy -> Privacy"
            alert.alertStyle = .warning
            alert.runModal()
        }

        #if DEBUG
            togglePreferencesWindow()
        #endif
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        state.saveToDisk()
    }

    func enable(_ flag: Bool) {
        state.appIsEnabled = flag
        menuBarItem?.image = flag ? iconOn : iconOff
        enabledIndicator.title = "\(appName): \(flag ? "on" : "off")"
    }

    func setupIcon(_ image: NSImage?) {
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == .leftMouseUp {
            enable(!state.appIsEnabled)
        }
    }

    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc func togglePreferencesWindow() {
        if window.isVisible {
            window.close()
        } else {
            window.center()
            window.makeKeyAndOrderFront(window)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}

