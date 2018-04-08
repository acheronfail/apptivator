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

// This is a copy of an NSMenuItem that allows an image at the start, as well as allowing a custom
// string where the "keyEquivalent" text would normally be (we want to be able to show key sequences
// in the "keyEquivalent" text, which is normally unsupported).
class MultiMenuItem: NSBox {
    override func awakeFromNib() {
        self.alphaValue = 0.5
    }

    // Getting the native "highlight" background on an NSMenuItem with a custom view is unnecesarily
    // difficult, so just have a simple alpha-highlight. See:
    // https://stackoverflow.com/q/26851306/5552584
    // https://stackoverflow.com/q/6054331/5552584
    // https://stackoverflow.com/q/30617085/5552584
    override func draw(_ dirtyRect: NSRect) {
        self.alphaValue = self.enclosingMenuItem!.isHighlighted ? 0.5 : 1.0
        super.draw(dirtyRect)
    }

    // Simulate a click on the menu item.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let menuItem = self.enclosingMenuItem {
            menuItem.menu?.cancelTracking()
            (menuItem.representedObject as? ApplicationEntry)?.apptivate()
        }
    }
}

// A View Controller for the above view, to handle instantiation and management of the view easier.
class MultiMenuItemController: NSViewController {
    var image: NSImage?
    var label: String?
    var detail: String?

    @IBOutlet var wrapper: NSBox!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var detailTextField: NSTextField!

    // Create and return the view managed by this controller.
    static func viewFor(entry: ApplicationEntry) -> NSView {
        let controller = MultiMenuItemController()
        controller.label = entry.name
        controller.image = entry.icon
        controller.detail = entry.shortcutAsString
        return controller.view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = image ?? nil
        self.labelTextField!.stringValue = label ?? ""
        self.detailTextField!.stringValue = detail ?? ""
        self.sizeToFit()
    }

    // Resize the menu item to fit all its children.
    func sizeToFit() {
        self.labelTextField.sizeToFit()
        self.detailTextField.sizeToFit()
        // 50 is the view's margins, its padding and the spacing between title & detail text.
        self.view.frame.size.width = self.labelTextField.frame.width + self.detailTextField.frame.width + 50
    }
}
