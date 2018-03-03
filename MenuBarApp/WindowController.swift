//
//  WindowController.swift
//  MenuBarApp
//
//  Created by Callum Osmotherly on 3/3/18.
//  Copyright © 2018 Wallace Wang. All rights reserved.
//

import Cocoa
import MASShortcut

struct ApplicationEntry: CustomDebugStringConvertible {
    let name: String
    let icon: NSImage
    let url: URL
    let shortcut: MASShortcut
    
    init(fileURL: URL, name: String, icon: NSImage, shortcut: MASShortcut) {
        self.name = name
        self.icon = icon
        self.url = fileURL
        self.shortcut = shortcut
    }
    
    public var debugDescription: String {
        return name + " " + "Shortcut: \(shortcut)"
    }
}

class WindowController: NSWindowController {
    
    // Shortcuts window.
//    @IBOutlet weak var window: NSWindow!
    // Table in Shortcuts window.
//    @IBOutlet weak var tableView: NSTableView!
    // Items
//    var items: [ApplicationEntry]?

    override func windowDidLoad() {
        super.windowDidLoad()
        
//        tableView.delegate = self
//        tableView.dataSource = self
        
        print("Hello, World!")
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

}
//
//extension WindowController: NSTableViewDataSource {
//    func numberOfRows(in tableView: NSTableView) -> Int {
//        return items?.count ?? 0
//    }
//}
//
//extension WindowController: NSTableViewDelegate {
//
//    fileprivate enum CellIdentifiers {
//        static let ApplicationCell = "ApplicationCellID"
//        static let ShortcutCell = "ShortcutCellID"
//    }
//
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        var image: NSImage?
//        var text: String = ""
//        var cellIdentifier: String = ""
//
//        guard let item = items?[row] else {
//            return nil
//        }
//
//        if tableColumn == tableView.tableColumns[0] {
//            image = item.icon
//            text = item.name
//            cellIdentifier = CellIdentifiers.ApplicationCell
//        } else if tableColumn == tableView.tableColumns[1] {
//            text = "shortcut here"
//            cellIdentifier = CellIdentifiers.ShortcutCell
//        }
//
//        if let cell = tableView.makeView(withIdentifier: .init(cellIdentifier), owner: nil) as? NSTableCellView {
//            cell.textField?.stringValue = text
//            cell.imageView?.image = image ?? nil
//            return cell
//        }
//        return nil
//    }
//
//}

