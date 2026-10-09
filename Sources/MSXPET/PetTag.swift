// PetTag: tiny name pill floating above the pet. Shown only when the
// clowder has 2+ members (so you can tell the chaos apart). Follows the
// pet like the speech bubble; sits just above it (bubbles float higher).

import AppKit

public final class PetTag {
    private let window: NSPanel
    private let label: NSTextField
    private var currentName = ""
    private var shown = false

    public init() {
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 64, height: 18),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        label = NSTextField(frame: NSRect(x: 0, y: 0, width: 64, height: 18))
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        label.layer?.cornerRadius = 7
        window.contentView?.addSubview(label)
        window.orderOut(nil)
    }

    public func update(name: String, show: Bool, above petOrigin: NSPoint,
                       petSize: CGFloat, visibleRect: CGRect) {
        if !show {
            if shown { shown = false; window.orderOut(nil) }
            return
        }
        if name != currentName {
            currentName = name
            label.stringValue = name
            label.sizeToFit()
            let w = min(max(label.frame.width + 14, 30), 130)
            window.setContentSize(NSSize(width: w, height: 18))
            label.frame = NSRect(x: 0, y: 0, width: w, height: 18)
        }
        let w = window.frame.width
        var tx = petOrigin.x + petSize / 2 - w / 2
        var ty = petOrigin.y + petSize + 2
        tx = min(max(tx, visibleRect.minX + 8), visibleRect.maxX - w - 8)
        ty = min(max(ty, visibleRect.minY + 8), visibleRect.maxY - 18 - 8)
        window.setFrameOrigin(NSPoint(x: tx, y: ty))
        if !shown { shown = true; window.orderFront(nil) }
    }

    public func hide() {
        shown = false
        window.orderOut(nil)
    }
}
