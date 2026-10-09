// PetView: renders current frame + implements transparency click-through.
// Replaces upstream XShapeCombineMask with per-pixel alpha hit-testing.

import AppKit

public final class PetView: NSView {
    public var currentImage: NSImage? {
        didSet {
            if let img = currentImage { cacheAlpha(image: img) }
            needsDisplay = true
        }
    }

    private var alphaMask: (pixels: [UInt8], width: Int, height: Int)?

    // Absolute screen-space drag (NSEvent.mouseLocation coords, Y-up —
    // the same space PetEngine lives in). Deliberately NOT window-relative
    // deltas: the window moves under the cursor during a drag, so deltas
    // eat their own tail and the pet falls behind (measured 620pt gap
    // after a 1s fast pull). Upstream was absolute too (XQueryPointer).
    public var onDragStart: ((CGPoint) -> Void)?
    public var onDragMove: ((CGPoint) -> Void)?
    public var onDragEnd: (() -> Void)?
    public var onClick: (() -> Void)?
    public var onHover: (() -> Void)?
    private var downScreen: CGPoint?
    private var movedSinceDown = false
    private static let clickThreshold: CGFloat = 3

    override public var isFlipped: Bool { true }

    /// Sleeping Zzz particles (view coords, y-down). Set by PetManager.
    public var zzz: [ZParticle] = [] {
        didSet { needsDisplay = true }
    }

    /// Accessory overlays (full-canvas 32px layers). Set by PetManager.
    public var overlays: [Overlay] = [] {
        didSet { needsDisplay = true }
    }

    /// Current animation state dir (e.g. "walk_east") for variant art.
    public var overlayState: String = "idle"
    public var overlayFrame: Int = 0

    /// Head-tracking shift in 32px art units (y-down, like the canvas).
    /// Pet sets this per animation frame so hats ride the bobble.
    public var overlayShift = CGVector.zero {
        didSet {
            if overlayShift != oldValue { needsDisplay = true }
        }
    }

    override public func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        // Crisp pixel-art on Retina: no smoothing on upscale 32px -> 64pt.
        NSGraphicsContext.current?.imageInterpolation = .none
        currentImage?.draw(in: bounds)
        let r = NSRect(x: bounds.origin.x + overlayShift.dx * 2,
                       y: bounds.origin.y + overlayShift.dy * 2,
                       width: bounds.width, height: bounds.height)
        for o in overlays { o.image(for: overlayState, frame: overlayFrame).draw(in: r) }
        drawZzz()
    }

    private func drawZzz() {
        for z in zzz {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: z.size, weight: .bold),
                .foregroundColor: NSColor.systemBlue.withAlphaComponent(z.alpha),
            ]
            ("z" as NSString).draw(at: NSPoint(x: z.x, y: z.y), withAttributes: attrs)
        }
    }

    private func cacheAlpha(image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        pixels.withUnsafeMutableBytes { ptr in
            if let ctx = CGContext(data: ptr.baseAddress, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: cs, bitmapInfo: info.rawValue) {
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }
        alphaMask = (pixels, w, h)
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        guard let mask = alphaMask else { return nil }
        // Map view point -> image pixel (handles Retina scaling via bounds ratio)
        let fx = point.x / max(bounds.width, 1) * CGFloat(mask.width)
        let fy = point.y / max(bounds.height, 1) * CGFloat(mask.height)
        let px = Int(fx), py = Int(fy)
        guard px >= 0, py >= 0, px < mask.width, py < mask.height else { return nil }
        // Both the pixel buffer (verified byte-for-byte: row 0 = image top)
        // and this flipped view are top-down — no row flip.
        let offset = (py * mask.width + px) * 4 + 3
        if mask.pixels[offset] > 20 { return super.hitTest(point) }
        return nil // click-through to desktop
    }

    override public func mouseDown(with event: NSEvent) {
        _ = event
        downScreen = NSEvent.mouseLocation
        movedSinceDown = false
    }

    override public func mouseDragged(with event: NSEvent) {
        _ = event
        guard let down = downScreen else { return }
        let now = NSEvent.mouseLocation
        if !movedSinceDown,
           hypot(now.x - down.x, now.y - down.y) > Self.clickThreshold {
            movedSinceDown = true
            onDragStart?(down)
        }
        if movedSinceDown { onDragMove?(now) }
    }

    override public func mouseUp(with event: NSEvent) {
        _ = event
        downScreen = nil
        if movedSinceDown { onDragEnd?() }
        else { onClick?() }
        movedSinceDown = false
    }

    override public func rightMouseDown(with event: NSEvent) {
        _ = event
        onClick?()
    }

    // Hover pets: cursor brushes (no click) earn a wiggle. Tracking areas
    // fire on the frame regardless of the alpha hit-test.
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override public func mouseEntered(with event: NSEvent) {
        _ = event
        onHover?()
    }
}
