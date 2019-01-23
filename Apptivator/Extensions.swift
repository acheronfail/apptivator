//
//  Extensions.swift
//  Apptivator
//

// http://homecoffeecode.com/nsimage-tinted-as-easily-as-a-uiimage/
extension NSImage {
    func tinted(with tintColor: NSColor) -> NSImage {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return self }
        
        return NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            tintColor.set()
            context.clip(to: bounds, mask: cgImage)
            context.fill(bounds)
            return true
        }
    }
}
