// SpeechBubble: separate borderless panel above the pet.
// Upstream used a second override_redirect window; Qwen's subview approach
// broke hit-testing and layout, so we keep a dedicated window here.

import AppKit

public final class SpeechBubble {
    public let window: NSPanel
    private let label: NSTextField
    private var hideWork: DispatchWorkItem?

    public init() {
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 120, height: 28),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        label = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        label.isEditable = false
        label.isBordered = true
        label.backgroundColor = .white
        label.textColor = .black
        label.font = .systemFont(ofSize: 11)
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        window.contentView?.addSubview(label)
        window.orderOut(nil)
    }

    public func show(text: String, above petOrigin: NSPoint, petSize: CGFloat, visibleRect: CGRect) {
        hideWork?.cancel()
        label.stringValue = text
        label.sizeToFit()
        var w = max(label.frame.width + 16, 60)
        let h: CGFloat = 26
        w = min(w, 320)
        var bx = petOrigin.x + petSize / 2 - w / 2
        var by = petOrigin.y + petSize + 8
        bx = min(max(bx, visibleRect.minX + 8), visibleRect.maxX - w - 8)
        by = min(max(by, visibleRect.minY + 8), visibleRect.maxY - h - 8)
        window.setFrame(NSRect(x: bx, y: by, width: w, height: h), display: true)
        label.frame = NSRect(x: 0, y: 0, width: w, height: h)
        window.orderFront(nil)
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(Config.speechDurationMs) / 1000.0, execute: work)
    }

    public func hide() {
        hideWork?.cancel()
        window.orderOut(nil)
    }
}
