// PetWindow: borderless, transparent, floating panel. Mirrors upstream
// override_redirect + XRaiseWindow semantics using AppKit levels.

import AppKit

public final class PetWindow: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }
}
