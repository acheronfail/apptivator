//
//  AppDelegate.swift
//  Apptivator
//

import SwiftyJSON

// Global application state.
let APP_NAME = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
#if DEBUG
let CFG_PATH = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(APP_NAME)-\(UUID().uuidString).json")
#else
let CFG_PATH = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(APP_NAME)/configuration.json")
#endif
let state = ApplicationState(atPath: CFG_PATH)

let ENABLED_INDICATOR_ON = "\(APP_NAME): on"
let ENABLED_INDICATOR_OFF = "\(APP_NAME): off"
let ICON_ON = NSImage(named: NSImage.Name(rawValue: "icon-on"))
let ICON_OFF = NSImage(named: NSImage.Name(rawValue: "icon-off"))

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var popover: NSPopover!
    @IBOutlet weak var popoverViewController: PopoverViewController!

    private var contextMenu: NSMenu = NSMenu()
    private var menuBarItem: NSStatusItem! = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let enabledIndicator = NSMenuItem(title: ENABLED_INDICATOR_OFF, action: nil, keyEquivalent: "")

    // The window must be at least 1x1 pixel in order for it to be drawn on the screen.
    // See @togglePreferencesPopover for why an invisible window exists.
    private let invisibleWindow = NSWindow(contentRect: NSMakeRect(0, 0, 1, 1), styleMask: .borderless, backing: .buffered, defer: false)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupIcon(ICON_ON)
        setupIcon(ICON_OFF)

        popover.delegate = self
        contextMenu.delegate = self
        contextMenu.autoenablesItems = false
        enabledIndicator.isEnabled = false

        invisibleWindow.alphaValue = 0
        invisibleWindow.hidesOnDeactivate = true
        invisibleWindow.collectionBehavior = .canJoinAllSpaces

        menuBarItem.image = ICON_OFF
        menuBarItem.action = #selector(onMenuClick)
        menuBarItem.sendAction(on: [.leftMouseUp, .rightMouseUp])

        state.loadFromDisk()
        enable(state.isEnabled)
        popoverViewController.reloadView()

        // Check for accessibility permissions.
        if !UIElement.isProcessTrusted(withPrompt: true) {
            let alert = NSAlert()
            alert.messageText = "Action Required"
            alert.informativeText = "\(APP_NAME) requires access to the accessibility API in order to hide/show other application's windows.\n\nPlease open System Preferences and allow \(APP_NAME) access.\n\nSystem Preferences -> Security & Privacy -> Privacy"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        state.saveToDisk()
    }

    func enable(_ flag: Bool) {
        state.isEnabled = flag
        menuBarItem?.image = flag ? ICON_ON : ICON_OFF
        enabledIndicator.title = flag ? ENABLED_INDICATOR_ON : ENABLED_INDICATOR_OFF
    }

    func setupIcon(_ image: NSImage?) {
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let leftClickToggles = state.defaults.bool(forKey: "leftClickToggles")
        let toggleEvent: NSEvent.EventType = leftClickToggles ? .leftMouseUp : .rightMouseUp
        let dropdownEvent: NSEvent.EventType = leftClickToggles ? .rightMouseUp : .leftMouseUp

        let event = NSApp.currentEvent!
        if event.type == dropdownEvent {
            buildContextMenu(state.entries)
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == toggleEvent {
            enable(!state.isEnabled)
        }
    }

    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // NSPopovers will follow the view they are relative to, even if it moves. Apps like Bartender
    // that control the menubar can move the menu bar item, which moves and janks the popover
    // around. We get around this by attaching it to a tiny, invisible window whose location we
    // can control.
    @objc func togglePreferencesPopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Get the screen coords of the menu bar item's current location.
            let menuBarButton = menuBarItem.button!
            let buttonBounds = menuBarButton.convert(menuBarButton.bounds, to: nil)
            let screenBounds = menuBarButton.window!.convertToScreen(buttonBounds)

            var xPosition: CGFloat
            if state.defaults.bool(forKey: "showPopoverOnScreenWithMouse"), let screen = getScreenWithMouse() {
                xPosition = screen.frame.origin.x + screen.frame.width - 1
            } else {
                // Account for Bartender moving the menu bar item offscreen. If the midpoint doesn't
                // seem to be on the main screen, then place the popover in the top-right corner.
                let screenFrame = NSScreen.main!.frame
                xPosition = screenBounds.midX
                if abs(xPosition) > screenFrame.width {
                    xPosition = screenFrame.origin.x + screenFrame.width - 1
                }
            }

            // Move the window to the coords, and activate the popover on the window.
            invisibleWindow.setFrameOrigin(NSPoint(x: xPosition, y: screenBounds.origin.y))
            invisibleWindow.makeKeyAndOrderFront(nil)
            popover.show(relativeTo: invisibleWindow.contentView!.frame, of: invisibleWindow.contentView!, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}

extension AppDelegate: NSMenuDelegate {
    func buildContextMenu(_ entries: [ApplicationEntry]) {
        contextMenu.addItem(enabledIndicator)
        contextMenu.addItem(NSMenuItem(title: "Configure Shortcuts", action: #selector(togglePreferencesPopover), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Active applications", action: nil, keyEquivalent: ""))
        contextMenu.item(at: contextMenu.numberOfItems - 1)?.isEnabled = false

        for entry in entries {
            // Try and attach observer to app here if none is unattached.
            if !entry.isActive, let runningApp = findRunningApp(withURL: entry.url) {
                entry.createObserver(runningApp)
            }
            if entry.isActive {
                let menuItem = NSMenuItem(title: entry.name, action: nil, keyEquivalent: "")
                menuItem.view = MultiMenuItemController.viewFor(entry: entry)
                menuItem.representedObject = entry
                contextMenu.addItem(menuItem)
            }
        }

        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: ""))
    }

    func menuDidClose(_ menu: NSMenu) {
        contextMenu.removeAllItems()
    }
}

extension AppDelegate: NSPopoverDelegate {
    // Allows the user to click + drag to move the popover around, where it can become a separate,
    // persistent window.
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
