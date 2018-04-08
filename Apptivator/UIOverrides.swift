//
//  MixedCheckbox.swift
//  Apptivator
//

// If `allowsMixedState` is set, when the user clicks the checkbox it will cycle states between
// on/off/mixed. We want the user to only be able check/uncheck the checkbox, so we have to override
// the getter on NSButtonCell in order for it to act the way we want.
class MixedCheckboxCell: NSButtonCell {
    override var nextState: Int {
        get {
            return self.state == .on ? 0 : 1
        }
    }
}

// TODO: doc
class MultiMenuItem: NSBox {
    override func awakeFromNib() {
        self.alphaValue = 0.5
    }

    override func draw(_ dirtyRect: NSRect) {
        // WTF?
        self.alphaValue = self.enclosingMenuItem!.isHighlighted ? 0.5 : 1.0
        super.draw(dirtyRect)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let menuItem = self.enclosingMenuItem {
            menuItem.menu?.cancelTracking()
            (menuItem.representedObject as? ApplicationEntry)?.apptivate()
        }
    }
}

// TODO: doc
class MultiMenuItemController: NSViewController {
    var image: NSImage?
    var detail: String?

    @IBOutlet var wrapper: NSBox!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var detailTextField: NSTextField!

    var watcher: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = image ?? nil
        self.titleTextField!.stringValue = title ?? ""
        self.detailTextField!.stringValue = detail ?? ""

        self.sizeToFit()
    }

    func sizeToFit() {
        self.titleTextField.sizeToFit()
        self.detailTextField.sizeToFit()
        self.view.frame.size.width = self.titleTextField.frame.width + self.detailTextField.frame.width + 50
    }
}
