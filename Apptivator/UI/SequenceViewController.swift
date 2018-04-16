//
//  SequenceViewController.swift
//  Apptivator
//

class SequenceView: NSBox {
    // TODO: doc
    override func mouseDown(with event: NSEvent) {}
}

class SequenceViewController: NSViewController {
    var beforeAdded: (() -> Void)?
    var afterAdded: (() -> Void)?
    var beforeRemoved: (() -> Void)?
    var afterRemoved: (() -> Void)?

    var clipView: NSView!
    var watchers: [NSKeyValueObservation?] = []
    var sequence: [MASShortcutView] = []
    var entry: ApplicationEntry! {
        didSet {
            // Copy the sequence
            sequence = entry.sequence.map({ view in
                let viewCopy = MASShortcutView()
                // TODO: doc
                if let shortcut = view.shortcutValue {
                    viewCopy.shortcutValue = MASShortcut(keyCode: shortcut.keyCode, modifierFlags: shortcut.modifierFlags)
                    watchers.append(viewCopy.observe(\.isRecording, changeHandler: state.onRecordingChange))
                } else {
                    watchers.append(nil)
                }
                return viewCopy
            })
        }
    }

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var imageView: NSImageView!
    
    @IBAction func closeButtonClick(_ sender: Any) {
        slideOutAndRemove()
    }

    @IBAction func saveButtonClick(_ sender: Any) {
        // TODO: validate sequence here
        let sequence = self.sequence.filter({ $0.shortcutValue != nil })
        if let conflictingEntry = state.checkForConflictingSequence(sequence, excluding: self.entry) {
            // TODO: alert? update UI?
            print(conflictingEntry)
        } else {
            entry.sequence = sequence
            slideOutAndRemove()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        imageView.image = entry.icon
    }

    func addShortcut() {
        sequence.append(MASShortcutView())
        tableView.reloadData()
    }

    func removeShortcut() {
        let _ = sequence.popLast()
        tableView.reloadData()
    }

    // TODO: doc
    func runAnimation(_ f: () -> Void, done: (() -> Void)?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = .init(name: kCAMediaTimingFunctionEaseInEaseOut)
            context.allowsImplicitAnimation = true
            f()
        }, completionHandler: done)
    }

    // TODO: slide other views over while this slides in?
    // TODO: or, have this underneath, and slide out above view?
    func slideInAndAdd(to referenceView: NSView) {
        beforeAdded?()
        clipView = referenceView
        view.alphaValue = 0.0
        view.frame.size = clipView.frame.size
        view.frame.origin = CGPoint(x: clipView.frame.maxX, y: clipView.frame.minY)
        clipView.superview!.addSubview(self.view)
        runAnimation({
            self.view.animator().frame.origin = clipView.frame.origin
            self.view.animator().alphaValue = 1.0
        }, done: {
            self.afterAdded?()
        })
    }

    func slideOutAndRemove() {
        beforeRemoved?()
        let destination = CGPoint(x: clipView.frame.maxX, y: clipView.frame.minY)
        runAnimation({
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
        return sequence[row]
    }
}

extension SequenceViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sequence.count
    }
}
