//
//  AppDelegate.swift
//  MenuBarApp
//

import Cocoa
import MASShortcut

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // Shortcuts window.
    @IBOutlet weak var window: NSWindow!
    // The actual menu bar item.
    var menuBarItem: NSStatusItem? = nil
    // The menu.
    var contextMenu: NSMenu = NSMenu()
    // Whether or not the shortcuts are enabled.
    var enabled: Bool = true
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Shortcuts", action: #selector(AppDelegate.shortcuts), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(AppDelegate.quitApplication), keyEquivalent: ""))
        
        menuBarItem?.title = "enabled"
        menuBarItem?.action = #selector(AppDelegate.onMenuClick)
        menuBarItem?.sendAction(on: [NSEvent.EventTypeMask.leftMouseDown, NSEvent.EventTypeMask.rightMouseDown])
    }
    
    @objc func onMenuClick(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseDown {
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == .leftMouseDown {
            enabled ? disable() : enable()
        }
    }
    
    func enable() {
        enabled = true
        menuBarItem?.title = "enabled"
    }
    
    func disable() {
        enabled = false
        menuBarItem?.title = "disabled"
    }
    
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel()
    }
    
    @objc func shortcuts() {
        window.center()
        window.makeKeyAndOrderFront(window)
        // TODO: map apps -> shortcuts
    }
    
    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

