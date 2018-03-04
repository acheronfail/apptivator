//
//  ViewController.swift
//  Apptivator
//

import MASShortcut

class ViewController: NSViewController {
    
    var entries: [ApplicationEntry] = []

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadEntriesFromDisk(&entries)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        addButton.action = #selector(addApplication(_:))
        removeButton.action = #selector(removeApplication(_:))
    }
    
    override func viewWillDisappear() {
        saveEntriesToDisk(entries)
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
                entries.append(appEntry)
                tableView.reloadData()
            } catch {
                print("Error reading file attributes")
            }
        }
    }
    
    @objc func removeApplication(_ sender: NSButton) {
        let selected = tableView.selectedRow
        if selected >= 0 {
            let entry = entries.remove(at: selected)
            MASShortcutBinder.shared().breakBinding(withDefaultsKey: entry.key)
            tableView.reloadData()
        }
    }
    
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }
}

extension ViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let ApplicationCell = "ApplicationCellID"
        static let ShortcutCell = "ShortcutCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = entries[row]
        
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
