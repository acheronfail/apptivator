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

// Just add an index property onto the button so we can know which table row it came from.
class ShortcutButton: NSButton {
    var index: Int?
}

// This is a copy of an NSMenuItem that allows an image at the start, as well as allowing a custom
// string where the "keyEquivalent" text would normally be (we want to be able to show key sequences
// in the "keyEquivalent" text, which is normally unsupported).
//
// Also, getting the native "highlight" background on an NSMenuItem with a custom view is
// unnecesarily difficult, so here we just have a simple alpha-highlight. See:
// https://stackoverflow.com/q/26851306/5552584
// https://stackoverflow.com/q/6054331/5552584
// https://stackoverflow.com/q/30617085/5552584
class MultiMenuItem: NSView {
    var mouseDownInside = false
    var trackingArea : NSTrackingArea?

    override func awakeFromNib() {
        self.alphaValue = 0.5
    }

    override func updateTrackingAreas() {
        if trackingArea != nil { self.removeTrackingArea(trackingArea!) }
        let options: NSTrackingArea.Options = [.activeInActiveApp, .mouseEnteredAndExited, .enabledDuringMouseDrag]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        self.alphaValue = 1.0
    }

    override func mouseExited(with event: NSEvent) {
        self.alphaValue = 0.5
        mouseDownInside = false
    }

    // FIXME: for some reason `mouseDown` and `mouseUp` don't always get fired when clicking on the
    // image view - this may be a bug since the directly subclassing NSImageView and listening there
    // also doesn't help.
    override func mouseDown(with event: NSEvent) {
        mouseDownInside = true
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownInside, let menuItem = self.enclosingMenuItem {
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

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var detailTextField: NSTextField!

    // Create and return the view managed by this controller.
    static func viewFor(entry: ApplicationEntry) -> NSView {
        let controller = MultiMenuItemController()
        controller.label = entry.name
        controller.image = entry.icon
        controller.detail = entry.shortcutString
        return controller.view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = image ?? nil
        self.labelTextField!.stringValue = label ?? ""
        self.detailTextField!.stringValue = detail ?? ""
        self.sizeToFit()
        self.view.autoresizingMask = [.width]
    }

    // Resize the menu item to fit all its children.
    func sizeToFit() {
        self.labelTextField.sizeToFit()
        self.detailTextField.sizeToFit()
        // 50 is the view's margins, its padding and the spacing between title & detail text.
        self.view.frame.size.width = self.labelTextField.frame.width + self.detailTextField.frame.width + 50
    }
}
