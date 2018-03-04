//
//  AppDelegate.swift
//  MenuBarApp
//

import Cocoa
import AXSwift
import MASShortcut
import SwiftyJSON

// Whether or not the shortcuts are enabled.
var appIsEnabled = true
// Where the app -> shortcut mappings are stored.
let entrySavePath = URL(fileURLWithPath: "/Users/acheronfail/Desktop/output.json")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // Shortcuts window.
    @IBOutlet weak var window: NSWindow!
    // Table in Shortcuts window.
    @IBOutlet weak var tableView: NSTableView!
    // Items.
    var items: [ApplicationEntry] = []
    // Buttons.
    @IBOutlet weak var addApplicationButton: NSButton!
    @IBOutlet weak var removeApplicationButton: NSButton!
    
    // The actual menu bar item.
    var menuBarItem: NSStatusItem? = nil
    // The menu.
    var contextMenu: NSMenu = NSMenu()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        loadItemsFromDisk(&items)
    
        tableView.delegate = self
        tableView.dataSource = self
        
        addApplicationButton.action = #selector(addApplication(_:))
        removeApplicationButton.action = #selector(removeApplication(_:))
        
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(about), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Shortcuts", action: #selector(shortcuts), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitApplication), keyEquivalent: ""))
        
        menuBarItem?.title = "enabled"
        menuBarItem?.action = #selector(onMenuClick)
        menuBarItem?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
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
    
    @objc func addApplication(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = NSURL.fileURL(withPath: "/Applications")
        panel.runModal()
        
        if let url = panel.url {
            do {
                let properties = try (url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
                let appEntry = ApplicationEntry(
                    url: url,
                    name: properties[.localizedNameKey] as? String ?? "",
                    icon: properties[.effectiveIconKey] as? NSImage ?? NSImage(),
                    shortcut: MASShortcut()
                )
                items.append(appEntry)
                tableView.reloadData()
            } catch {
                print("Error reading file attributes")
            }
        }
    }
    
    @objc func removeApplication(_ sender: NSButton) {
        let selected = tableView.selectedRow
        if selected >= 0 {
            let item = items.remove(at: selected)
            MASShortcutBinder.shared().breakBinding(withDefaultsKey: item.key)
            tableView.reloadData()
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
        saveItemsToDisk(items)
    }


}

extension AppDelegate: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
}

extension AppDelegate: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let ApplicationCell = "ApplicationCellID"
        static let ShortcutCell = "ShortcutCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        
        // Application column:
        if tableColumn == tableView.tableColumns[0] {
            if let cell = tableView.makeView(withIdentifier: .init(CellIdentifiers.ApplicationCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.name
                cell.imageView?.image = item.icon
                return cell
            }
        }
        
        // Shortcut column:
        if tableColumn == tableView.tableColumns[1] {
            return item.shortcutCell
        }

        return nil
    }
    
}















