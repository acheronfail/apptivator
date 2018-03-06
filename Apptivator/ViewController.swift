//
//  ViewController.swift
//  Apptivator
//

import MASShortcut

class ViewController: NSViewController {

    var addMenu: NSMenu = NSMenu()
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var appDelegate: AppDelegate!

    @IBOutlet weak var hideAppsWithShortcutWhenActive: NSButton!
    @IBOutlet weak var hideAppsWhenDeactivated: NSButton!
    @IBOutlet weak var launchAppIfNotRunning: NSButton!
    @IBOutlet weak var launchAppAtLogin: NSButton!

    @IBAction func onCheckboxChange(_ sender: NSButton) {
        if let identifier = sender.identifier?.rawValue {
            state.setValue(sender.state == .on, forKey: identifier)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        addMenu.delegate = self
        addMenu.addItem(NSMenuItem(title: "Choose from File System", action: #selector(chooseFromFileSystem), keyEquivalent: ""))
        addMenu.addItem(NSMenuItem(title: "Choose from Running Applications", action: nil, keyEquivalent: ""))
        addMenu.item(at: 1)?.submenu = NSMenu()

        addButton.action = #selector(addApplication(_:))
        removeButton.action = #selector(removeApplication(_:))
    }

    override func viewWillDisappear() {
        state.saveToDisk()
    }

    func reloadView() {
        tableView.reloadData()
        hideAppsWithShortcutWhenActive.state = state.hideAppsWithShortcutWhenActive ? .on : .off
        hideAppsWhenDeactivated.state = state.hideAppsWhenDeactivated ? .on : .off
        launchAppIfNotRunning.state = state.launchAppIfNotRunning ? .on : .off
        // TODO: launch app at login
    }

    @objc func addApplication(_ sender: NSButton) {
        addMenu.popUp(positioning: addMenu.item(at: 0), at: NSEvent.mouseLocation, in: nil)
    }

    @objc func chooseFromRunningApps(_ sender: NSMenuItem) {
        guard let app = sender.representedObject else {
            return
        }

        if let url = (app as! NSRunningApplication).bundleURL {
            addEntry(fromURL: url)
        } else if let url = (app as! NSRunningApplication).executableURL {
            addEntry(fromURL: url)
        }
    }
    
    @objc func chooseFromFileSystem() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = NSURL.fileURL(withPath: "/Applications")
        panel.runModal()
        
        if let url = panel.url {
            addEntry(fromURL: url)
        }
    }

    @objc func removeApplication(_ sender: NSButton) {
        let selected = tableView.selectedRow
        if selected >= 0 {
            let entry = state.entries.remove(at: selected)
            MASShortcutBinder.shared().breakBinding(withDefaultsKey: entry.key)
            tableView.reloadData()
        }
    }
    
    func addEntry(fromURL url: URL) {
        do {
            let properties = try (url as NSURL).resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
            let appEntry = ApplicationEntry(
                url: url,
                name: properties[.localizedNameKey] as? String ?? "",
                icon: properties[.effectiveIconKey] as? NSImage ?? NSImage(),
                shortcut: MASShortcut()
            )
            state.entries.append(appEntry)
            tableView.reloadData()
        } catch {
            print("Error reading file attributes")
        }
    }
}

extension ViewController: NSMenuDelegate {
    // Populate context menu with a list of running apps when it's highlighted.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard let item = item, item == addMenu.item(at: 1) else {
            addMenu.item(at: 1)?.submenu?.removeAllItems()
            return
        }

        let runningAppsMenu = item.submenu!
        for runningApp in NSWorkspace.shared.runningApplications {
            if runningApp.activationPolicy == .regular {
                let appItem = NSMenuItem(title: runningApp.localizedName!, action: #selector(chooseFromRunningApps(_:)), keyEquivalent: "")
                appItem.image = runningApp.icon
                appItem.representedObject = runningApp
                runningAppsMenu.addItem(appItem)
            }
        }
        item.submenu = runningAppsMenu
    }

    func menuDidClose(_ menu: NSMenu) {
        addMenu.item(at: 1)?.submenu?.removeAllItems()
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return state.entries.count
    }
}

extension ViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let ApplicationCell = "ApplicationCellID"
        static let ShortcutCell = "ShortcutCellID"
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        if tableView.sortDescriptors[0].ascending {
            state.entries.sort { $0.name.lowercased() < $1.name.lowercased() }
        } else {
            state.entries.sort { $0.name.lowercased() > $1.name.lowercased() }
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = state.entries[row]

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
