//
//  SequenceViewController.swift
//  Apptivator
//

let SEQUENCE_DETAIL_TEXT = """
Your app will be activated after hitting the sequences in order.
With a certain delay.
"""

class SequenceViewController: NSViewController {
    // View animation lifecycle hooks.
    var beforeAdded: (() -> Void)?
    var afterAdded: (() -> Void)?
    var beforeRemoved: (() -> Void)?
    var afterRemoved: (() -> Void)?

    var referenceView: NSView!

    var list: [(MASShortcutView, NSKeyValueObservation)] = []
    var listAsSequence: [MASShortcutView] {
        // Filter out any nil values.
        get { return list.compactMap({ $0.0.shortcutValue != nil ? $0.0 : nil }) }
    }
    var entry: ApplicationEntry! {
        // Copy the entry's sequence (adding another shortcut on at the end).
        didSet {
            list = entry.sequence.map({
                newShortcut(withKeyCode: $0.shortcutValue.keyCode, modifierFlags: $0.shortcutValue.modifierFlags)
            })
            list.append(newShortcut(withKeyCode: nil, modifierFlags: nil))
        }
    }

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var detailTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var saveButton: NSButton!
    
    @IBAction func closeButtonClick(_ sender: Any) { slideOutAndRemove() }
    @IBAction func saveButtonClick(_ sender: Any) {
        let sequence = listAsSequence

        // This is a sanity check: the save button should never be enabled without a valid sequence.
        assert(sequence.count > 0, "sequence.count must be > 0")

        if state.checkForConflictingSequence(sequence, excluding: self.entry) == nil {
            entry.sequence = sequence
            slideOutAndRemove()
        } else {
            assertionFailure("tried to save with a conflicting sequence")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        imageView.image = entry.icon

        titleTextField.stringValue = "Editing sequence for \(entry.name)"
        detailTextField.stringValue = SEQUENCE_DETAIL_TEXT
    }

    // This should be the only way to create shortcuts to add to the editable list. Each shortcut is
    // paired with its recordingWatcher, so that we don't accidentally fire any other shortcuts when
    // the user is configuring these shortcuts.
    func newShortcut(withKeyCode keyCode: UInt?, modifierFlags: UInt?) -> (MASShortcutView, NSKeyValueObservation) {
        let view = MASShortcutView()
        if keyCode != nil && modifierFlags != nil {
            view.shortcutValue = MASShortcut(keyCode: keyCode!, modifierFlags: modifierFlags!)
        }
        view.shortcutValueChange = onChange
        let watcher = view.observe(\.isRecording, changeHandler: state.onRecordingChange)
        return (view, watcher)
    }

    // Whenever a shortcut's value changes, update the list.
    func onChange(_ view: MASShortcutView?) {
        // Remove nil entries from list (except last).
        for (i, _) in list.enumerated().reversed() {
            if list.count > 1 && list[i].0.shortcutValue == nil {
                let _ = list.remove(at: i)
            }
        }

        // Ensure there's always one more shortcut at the end of the list.
        if list.last?.0.shortcutValue != nil {
            list.append(newShortcut(withKeyCode: nil, modifierFlags: nil))
        }

        // Check for any conflicting entries.
        let sequence = listAsSequence
        if sequence.count == 0 {
            saveButton.isEnabled = false
        } else {
            if let conflictingEntry = state.checkForConflictingSequence(sequence, excluding: entry) {
                showConflictingEntry(conflictingEntry)
                saveButton.isEnabled = false
            } else {
                detailTextField.textColor = .black
                detailTextField.stringValue = SEQUENCE_DETAIL_TEXT
                saveButton.isEnabled = true
            }
        }

        tableView.reloadData()
    }

    // Update the view with information regarding a conflicting entry. Entries' sequences conflict
    // when you cannot fully type sequence A without first calling sequence B (this makes it
    // impossible to call sequence A, and is therefore forbidden).
    func showConflictingEntry(_ conflictingEntry: ApplicationEntry) {
        // TODO: a nicer attributed string ?
        detailTextField.textColor = .red
        detailTextField.stringValue = """
        Current sequence conflicts with:
        \(conflictingEntry.name)'s
        Sequence: "\(conflictingEntry.shortcutString!)"
        """
    }

    // Animate entering the view, making it the size of `referenceView` and sliding over the top
    // of it.
    func slideInAndAdd(to referringView: NSView) {
        beforeAdded?()
        referenceView = referringView
        self.view.alphaValue = 0.0
        self.view.frame.size = referenceView.frame.size
        self.view.frame.origin = CGPoint(x: referenceView.frame.maxX, y: referenceView.frame.minY)
        referenceView.superview!.addSubview(self.view)
        runAnimation({ _ in
            self.view.animator().frame.origin = referenceView.frame.origin
            self.view.animator().alphaValue = 1.0
        }, done: {
            self.afterAdded?()
        })
    }

    func slideOutAndRemove() {
        beforeRemoved?()
        let destination = CGPoint(x: referenceView.frame.maxX, y: referenceView.frame.minY)
        runAnimation({ _ in
            self.view.animator().frame.origin = destination
            self.view.animator().alphaValue = 0.0
        }, done: {
            self.view.removeFromSuperview()
            self.afterRemoved?()
        })
    }
}

extension SequenceViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return list[row].0
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}

extension SequenceViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return list.count
    }
}
