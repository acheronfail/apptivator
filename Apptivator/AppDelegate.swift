//
//  AppDelegate.swift
//  Apptivator
//

import SwiftyJSON

// Global application state.
let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
let state = ApplicationState()

let ENABLED_INDICATOR_ON = "\(appName): on"
let ENABLED_INDICATOR_OFF = "\(appName): off"

// Menu bar item icons.
let iconOn = NSImage(named: NSImage.Name(rawValue: "icon-on"))
let iconOff = NSImage(named: NSImage.Name(rawValue: "icon-off"))

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var popover: NSPopover!
    @IBOutlet weak var viewController: ViewController!

    var contextMenu: NSMenu = NSMenu()
    var menuBarItem: NSStatusItem! = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let enabledIndicator = NSMenuItem(title: ENABLED_INDICATOR_OFF, action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupIcon(iconOn)
        setupIcon(iconOff)

        popover.delegate = self

        menuBarItem.image = iconOff
        menuBarItem.action = #selector(onMenuClick)
        menuBarItem.sendAction(on: [.leftMouseUp, .rightMouseUp])

        contextMenu.addItem(enabledIndicator)
        contextMenu.addItem(NSMenuItem(title: "Configure Shortcuts", action: #selector(togglePreferencesPopover), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitApplication), keyEquivalent: ""))

        state.loadFromDisk()
        enable(state.appIsEnabled)
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
        //togglePreferencesPopover()
        #endif
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        state.saveToDisk()
    }

    func enable(_ flag: Bool) {
        state.appIsEnabled = flag
        menuBarItem?.image = flag ? iconOn : iconOff
        enabledIndicator.title = flag ? ENABLED_INDICATOR_ON : ENABLED_INDICATOR_OFF
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

    @objc func togglePreferencesPopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let button = menuBarItem.button!
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
