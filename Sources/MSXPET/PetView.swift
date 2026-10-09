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

    public var onDrag: ((CGFloat, CGFloat) -> Void)?
    public var onDragEnd: (() -> Void)?
    public var onClick: (() -> Void)?
    private var dragStart: NSPoint?
    private var movedSinceDown = false

    override public var isFlipped: Bool { true }

    override public func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        // Crisp pixel-art on Retina: no smoothing on upscale 32px -> 64pt.
        NSGraphicsContext.current?.imageInterpolation = .none
        currentImage?.draw(in: bounds)
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
        // CoreGraphics buffer is bottom-up; view is flipped (top-down) -> flip row
        let row = mask.height - 1 - py
        let offset = (row * mask.width + px) * 4 + 3
        if mask.pixels[offset] > 20 { return super.hitTest(point) }
        return nil // click-through to desktop
    }

    override public func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        movedSinceDown = false
    }

    override public func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let cur = event.locationInWindow
        let dx = cur.x - start.x
        let dy = -(cur.y - start.y) // window Y-up vs flipped view: dragging up = +screen Y
        // NOTE: PetManager converts to screen delta; sign fixed there. Keep raw here.
        if abs(dx) + abs(dy) > 1 { movedSinceDown = true }
        onDrag?(cur.x - start.x, start.y - cur.y)
        dragStart = cur
    }

    override public func mouseUp(with event: NSEvent) {
        _ = event
        dragStart = nil
        if movedSinceDown { onDragEnd?() }
        else { onClick?() }
        movedSinceDown = false
    }

    override public func rightMouseDown(with event: NSEvent) {
        _ = event
        onClick?()
    }
}
