//
//  APPopoverViewController.swift
//  Apptivator
//

import MASShortcut
import LaunchAtLogin
import CleanroomLogger

let toggleWindowShortcutKey = "__Apptivator_global_show__"

class APPopoverViewController: NSViewController {

    private var addMenu: NSMenu = NSMenu()
    @IBOutlet weak var clipView: NSClipView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var appDelegate: AppDelegate!
    @IBOutlet weak var boxWrapper: NSBox!
    @IBOutlet weak var bannerImage: NSImageView!
    @IBOutlet weak var toggleWindowShortcut: MASShortcutView!
    private var toggleWindowShortcutWatcher: NSKeyValueObservation!

    // Local configuration properties.
    var sequenceEditor: APSequenceViewController?
    @IBOutlet weak var hideWithShortcutWhenActive: NSButton!
    @IBOutlet weak var showOnScreenWithMouse: NSButton!
    @IBOutlet weak var hideWhenDeactivated: NSButton!
    @IBOutlet weak var launchIfNotRunning: NSButton!
    func getLocalConfigButtons() -> [NSButton] {
        return [
            hideWithShortcutWhenActive!,
            showOnScreenWithMouse!,
            hideWhenDeactivated!,
            launchIfNotRunning!
        ]
    }

    // Global configuration values.
    @IBOutlet weak var launchAppAtLogin: NSButton!
    @IBOutlet weak var enableDarkMode: NSButton!
    
    @IBAction func onLocalCheckboxChange(_ sender: NSButton) {
        for index in tableView.selectedRowIndexes {
            let entry = APState.shared.getEntry(at: index)
            for button in getLocalConfigButtons() {
                entry.config[button.identifier!.rawValue] = button.state == .on ? true : false
            }
        }
    }

    @IBAction func onGlobalCheckboxChange(_ sender: NSButton) {
        let flag = sender.state == .on
        if let identifier = sender.identifier?.rawValue {
            switch identifier {
            case "launchAppAtLogin":
                LaunchAtLogin.isEnabled = flag
            case "enableDarkMode":
                APState.shared.darkModeEnabled = flag
                toggleDarkMode(flag)
            default:
                Log.warning?.message("Unknown identifier encountered: \(identifier)")
            }
        }
    }

    @IBAction func onShortcutClick(_ sender: Any) {
        if let button = sender as? APShortcutButton, let index = button.index {
            showSequenceEditor(for: APState.shared.getEntry(at: index))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Default to Aqua appearance (Apptivator in Aqua looks better than Vibrant Light).
        if !mojaveDarkModeSupported() {
            view.appearance = NSAppearance(named: .aqua)
        } else {
            // Otherwise, disable the button in macOS 10.14 and above.
            enableDarkMode.state = .off
            enableDarkMode.isEnabled = false
            enableDarkMode.alphaValue = 0
            boxWrapper.fillColor = NSColor.windowBackgroundColor
        }

        bannerImage.image?.isTemplate = true

        tableView.delegate = self
        tableView.dataSource = self

        addMenu.delegate = self
        addMenu.addItem(withTitle: "Choose from File System", action: #selector(chooseFromFileSystem), keyEquivalent: "")
        let runningAppsItem = addMenu.addItem(withTitle: "Choose from Running Applications", action: nil, keyEquivalent: "")
        runningAppsItem.submenu = NSMenu()

        setupToggleWindowShortcut()

        // Only observe changes to APPLE_INTERFACE_STYLE if we're below macOS 10.14 (in 10.14 this
        // happens automatically and is inherited by the application's appearance).
        if !mojaveDarkModeSupported() {
            APState.shared.defaults.addObserver(self, forKeyPath: APPLE_INTERFACE_STYLE, options: [], context: nil)
        }
    }

    // If we're below 10.14, then we'll be looking for changes in APPLE_INTERFACE_STYLE. No observer
    // is added for versions below 10.14.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == APPLE_INTERFACE_STYLE && APState.shared.defaults.bool(forKey: "matchAppleInterfaceStyle") {
            APState.shared.darkModeEnabled = appleInterfaceStyleIsDark()
            reloadView()
        }
    }

    override func viewWillAppear() {
        if #available(OSX 10.14, *) {
            if let value = UserDefaults.standard.string(forKey: APPLE_INTERFACE_STYLE), value.lowercased() == "dark" {
                view.appearance = NSAppearance(named: .darkAqua)
            } else {
                view.appearance = NSAppearance(named: .aqua)
            }
        }
    }

    override func viewWillDisappear() {
        sequenceEditor?.slideOutAndRemove()
        APState.shared.saveToDisk()
        // Override currentlyRecording state when popover disappears. This is to handle when there
        // are errors recording shortcuts. See https://github.com/acheronfail/apptivator/pull/32
        APState.shared._currentlyRecording = false
    }

    var isSequenceEditorActive: Bool {
        get { return sequenceEditor != nil }
    }

    func showSequenceEditor(for entry: APAppEntry) {
        if !isSequenceEditorActive {
            sequenceEditor = APSequenceViewController()
            sequenceEditor!.beforeAdded = {
                APState.shared.unregisterShortcuts()
                self.addButton.isEnabled = false
                self.removeButton.isEnabled = false
                self.tableView.selectRowIndexes([], byExtendingSelection: false)
            }
            sequenceEditor!.beforeRemoved = {
                APState.shared.registerShortcuts()
                self.addButton.isEnabled = true
                self.removeButton.isEnabled = self.tableView.selectedRowIndexes.count > 0
                self.reloadView()
            }
            sequenceEditor!.afterRemoved = {
                self.sequenceEditor = nil
            }

            sequenceEditor!.entry = entry
            sequenceEditor!.slideInAndAdd(to: clipView)
        }
    }

    func setupToggleWindowShortcut() {
        toggleWindowShortcut.style = .texturedRect
        toggleWindowShortcut.associatedUserDefaultsKey = toggleWindowShortcutKey
        toggleWindowShortcutWatcher = toggleWindowShortcut.observe(\.isRecording, changeHandler: APState.shared.onRecordingChange)
        toggleWindowShortcut.shortcutValueChange = { _ in
            MASShortcutBinder.shared().bindShortcut(withDefaultsKey: toggleWindowShortcutKey, toAction: {
                if APState.shared.isEnabled { self.appDelegate.togglePreferencesPopover() }
            })
        }
        toggleWindowShortcut.shortcutValueChange(nil)
    }

    // Don't call this if we're 10.14 or later - in those versions we allow macOS to handle the
    // light and dark appearances itself.
    func toggleDarkMode(_ flag: Bool) {
        guard !mojaveDarkModeSupported() else { return }
        appDelegate.popover.appearance = NSAppearance(named: flag ? .vibrantDark : .aqua)
        boxWrapper.isTransparent = flag
        tableView.reloadData()
        sequenceEditor?.tableView.reloadData()
    }

    func reloadView() {
        // Reload and ensure dark mode is functional on macOS versions below 10.14.
        if !mojaveDarkModeSupported() {
            let darkModeEnabled = APState.shared.darkModeEnabled
            toggleDarkMode(darkModeEnabled)
            enableDarkMode.state = darkModeEnabled ? .on : .off
        }
        launchAppAtLogin.state = LaunchAtLogin.isEnabled ? .on : .off
        tableView.reloadData()
    }

    @IBAction func onAddClick(_ sender: NSButton) {
        guard !isSequenceEditorActive else { return }
        // The current event should still be the left-mouse-up event.
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(addMenu, with: event, for: addButton)
        }
    }

    @IBAction func onRemoveClick(_ sender: NSButton) {
        guard !isSequenceEditorActive else { return }
        for index in tableView.selectedRowIndexes.sorted(by: { $0 > $1 }) {
            APState.shared.removeEntry(at: index)
        }
        tableView.selectRowIndexes([], byExtendingSelection: false)
        tableView.reloadData()
    }
    
    @objc func chooseFromRunningApps(_ sender: NSMenuItem) {
        guard let app = sender.representedObject else { return }
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

        if let url = panel.url { addEntry(fromURL: url) }
        if !appDelegate.popover.isShown { appDelegate.togglePreferencesPopover() }
    }

    func addEntry(fromURL url: URL) {
        // Check if the entry already exists.
        if let entry = (APState.shared.getEntries().first { $0.url == url }) {
            let alert = NSAlert()
            alert.messageText = "Duplicate Entry"
            alert.informativeText = "The application \"\(entry.name)\" has already been added. Please edit its entry in the list, or remove it to add it again."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        if let appEntry = APAppEntry(url: url, config: nil) {
            APState.shared.addEntry(appEntry)
            tableView.reloadData()
        }
    }
}

extension APPopoverViewController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        addMenu.item(at: 1)?.submenu?.removeAllItems()
    }

    // Populate context menu with a list of running apps when it's highlighted.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard let menuItem = item, menuItem == addMenu.item(at: 1) else {
            addMenu.item(at: 1)?.submenu?.removeAllItems()
            return
        }

        // Get all running applications, sort them and add them to the menu.
        NSWorkspace.shared.runningApplications.compactMap({ runningApp in
            if runningApp.activationPolicy == .regular {
                let appItem = NSMenuItem(title: runningApp.localizedName!, action: #selector(chooseFromRunningApps(_:)), keyEquivalent: "")
                appItem.representedObject = runningApp
                appItem.image = runningApp.icon
                return appItem
            }
            return nil
        }).sorted(by: { a, b in
            return a.title.lowercased() < b.title.lowercased()
        }).forEach({ item in
            menuItem.submenu!.addItem(item)
        })
    }
}

extension APPopoverViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return APState.shared.getEntries().count
    }
}

extension APPopoverViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let ApplicationCell = "ApplicationCell"
        static let ShortcutCell = "ShortcutCell"
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        var localConfig = getLocalConfigButtons().map { ($0, nil as NSControl.StateValue?) }

        // Return and disable checkboxes if no rows are selected.
        let selectedIndexes = tableView.selectedRowIndexes
        if selectedIndexes.count < 1 {
            for (button, _) in localConfig {
                button.state = .off
                button.isEnabled = false
                removeButton.isEnabled = false
            }
            return
        }

        // Combine settings together: if one app has a flag on, and another off, then the checkbox
        // state will be `.mixed`.
        for index in selectedIndexes {
            let entry = APState.shared.getEntry(at: index)
            for (i, tuple) in localConfig.enumerated() {
                let (button, newState) = tuple
                let entryValue = entry.config[button.identifier!.rawValue]!
                if newState == nil {
                    localConfig[i].1 = entryValue ? .on : .off
                } else if newState == .on && !entryValue || newState == .off && entryValue {
                    localConfig[i].1 = .mixed
                }
            }
        }

        // Apply new states.
        removeButton.isEnabled = true
        for (button, newState) in localConfig {
            button.state = newState!
            button.isEnabled = true
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        if tableView.sortDescriptors[0].ascending {
            APState.shared.sortEntries(comparator: { $0.name.lowercased() < $1.name.lowercased() })
        } else {
            APState.shared.sortEntries(comparator: { $0.name.lowercased() > $1.name.lowercased() })
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = APState.shared.getEntry(at: row)

        // Application column:
        if tableColumn == tableView.tableColumns[0] {
            if let cell = tableView.makeView(withIdentifier: .init(CellIdentifiers.ApplicationCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.name
                cell.imageView?.image = item.icon
                cell.toolTip = item.url.path
                return cell
            }
        }

        // Shortcut column:
        if tableColumn == tableView.tableColumns[1] {
            if let cell = tableView.makeView(withIdentifier: .init(CellIdentifiers.ShortcutCell), owner: nil) as? NSTableCellView {
                if let button = cell.subviews.first as? APShortcutButton {
                    button.index = row
                    button.title = item.shortcutString ?? "click to configure"
                    button.action = #selector(onShortcutClick(_:))
                }
                return cell
            }
        }

        return nil
    }
}
