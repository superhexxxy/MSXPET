// LaserDot: the red dot for laser-pointer mode. A 16pt floating panel
// that follows the cursor while the pet chases it.

import AppKit

public final class LaserDot {
    private let window: PetWindow
    private let view: NSImageView

    public init() {
        window = PetWindow(contentRect: NSRect(x: 0, y: 0, width: 16, height: 16))
        view = NSImageView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        view.image = Self.dotImage()
        window.contentView = view
        window.orderOut(nil)
    }

    public func move(to screenPoint: NSPoint) {
        window.setFrameOrigin(NSPoint(x: screenPoint.x - 8, y: screenPoint.y - 8))
        if !window.isVisible { window.orderFrontRegardless() }
    }

    public func hide() {
        window.orderOut(nil)
    }

    private static func dotImage() -> NSImage {
        let img = NSImage(size: NSSize(width: 16, height: 16))
        img.lockFocus()
        NSColor.red.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 14, height: 14)).fill()
        NSColor.red.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 6, height: 6)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 2, height: 2)).fill()
        img.unlockFocus()
        return img
    }
}
