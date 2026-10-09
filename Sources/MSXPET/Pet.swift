// Pet: one live creature — engine + window + view + bubble + particles.
// PetManager owns a collection of these and a single shared timer.

import AppKit
import Foundation

public final class Pet {
    public var engine: PetEngine
    public let window: PetWindow
    private let view: PetView
    private let bubble = SpeechBubble()
    private var zzz = ZzzField()
    private var lastBubbleText: String?
    private var recentMoves: [(CGPoint, Date)] = []

    private var frames: [PetState: [NSImage]]
    private var anchors: [PetState: [CGPoint]] = [:]
    private var refAnchor = CGPoint(x: 16, y: 4)
    private var frameIndex = 0
    private var frameAccumMs = 0
    private var lastState: PetState = .idle
    private var lastOrigin = NSPoint(x: -1, y: -1)

    public var petName: String

    /// Sound outlet: PetManager connects this to SoundManager.play.
    public var soundHandler: ((SoundEvent) -> Void)?

    public init(petName: String, assets: ([PetState: [NSImage]], [PetState: [CGPoint]], CGPoint), at origin: CGPoint) {
        self.petName = petName
        self.frames = assets.0
        self.anchors = assets.1
        self.refAnchor = assets.2
        engine = PetEngine(x: origin.x, y: origin.y)
        window = PetWindow(contentRect: NSRect(x: origin.x - 32, y: origin.y - 32,
                                              width: Config.petSize, height: Config.petSize))
        view = PetView(frame: NSRect(x: 0, y: 0, width: Config.petSize, height: Config.petSize))
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        engine.pickRandomDestination(in: NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900), margin: Config.wanderMargin)

        view.onDragStart = { [weak self] pt in self?.handleDragStart(screen: pt) }
        view.onDragMove = { [weak self] pt in self?.handleDragMove(screen: pt) }
        view.onDragEnd = { [weak self] in self?.handleDragEnd() }
        view.onClick = { [weak self] in self?.handleClick() }

        updateWindowPosition()
        window.orderFrontRegardless()
    }

    public func close() {
        bubble.hide()
        window.orderOut(nil)
    }

    public func setFrames(_ frames: [PetState: [NSImage]], anchors: [PetState: [CGPoint]], ref: CGPoint, petName: String) {
        self.frames = frames
        self.anchors = anchors
        self.refAnchor = ref
        self.petName = petName
        frameIndex = 0; frameAccumMs = 0
    }

    public func applyOverlays(_ overlays: [Overlay]) {
        if view.overlays.map(\.name) == overlays.map(\.name) { return }
        view.overlays = overlays
    }

    /// True when this pet needs the fast 60Hz gear.
    public var needsFastTick: Bool {
        engine.dragging || engine.falling || engine.chasing
            || engine.state.isWalking || engine.state == .dragged
    }

    // MARK: - Input

    private func handleDragStart(screen: CGPoint) {
        if !engine.dragging { engine.beginDrag(mouseScreen: screen) }
        bubble.hide()
        lastBubbleText = engine.speech
        recentMoves = [(screen, Date())]
    }

    private func handleDragMove(screen: CGPoint) {
        if !engine.dragging { engine.beginDrag(mouseScreen: screen) }
        engine.dragTo(mouseScreen: screen)
        recentMoves.append((screen, Date()))
        let cutoff = Date().addingTimeInterval(-0.12)
        recentMoves.removeAll { $0.1 < cutoff }
        updateWindowPosition()
    }

    private func handleDragEnd() {
        engine.endDrag(in: visibleFrame(), releaseVelocity: releaseVelocity())
        recentMoves = []
    }

    private func releaseVelocity() -> CGVector {
        guard let first = recentMoves.first, let last = recentMoves.last,
              last.0 != first.0 else { return .zero }
        let dt = last.1.timeIntervalSince(first.1)
        guard dt > 0.01 else { return .zero }
        let v = CGVector(dx: (last.0.x - first.0.x) / CGFloat(dt),
                         dy: (last.0.y - first.0.y) / CGFloat(dt))
        let speed = hypot(v.dx, v.dy)
        guard speed > 1 else { return .zero }
        let capped = min(speed, 1200) / speed
        return CGVector(dx: v.dx * capped, dy: v.dy * capped)
    }

    private func handleClick() {
        engine.interact()
        showBubbleIfNew()
    }

    // MARK: - Per-tick

    public func tick(dtMs: Int, mouse: CGPoint, visibleRect: CGRect) {
        engine.update(dtMs: dtMs, mouse: mouse, visibleRect: visibleRect)
        if let cue = engine.soundCue {
            engine.soundCue = nil
            soundHandler?(cue)
        }
        showBubbleIfNew()
        zzz.update(dtMs: dtMs, active: engine.state == .sleeping)
        view.zzz = zzz.parts
        updateAnimation(dtMs: dtMs)
        updateWindowPosition()
    }

    public func showBubbleIfNew() {
        if let s = engine.speech {
            if s != lastBubbleText {
                lastBubbleText = s
                bubble.show(text: s, above: window.frame.origin,
                            petSize: Config.petSize, visibleRect: visibleFrame())
            }
        } else {
            lastBubbleText = nil
        }
    }

    private func updateAnimation(dtMs: Int) {
        let s = engine.state
        if s != lastState {
            if !(s.isWalking && lastState.isWalking) { frameIndex = 0; frameAccumMs = 0 }
            lastState = s
        }
        guard let list = frames[s], !list.isEmpty else { return }
        frameAccumMs += dtMs
        if frameAccumMs >= Config.frameDurationMs {
            frameAccumMs = 0
            frameIndex += 1
            if frameIndex >= list.count { frameIndex = 0 }
        }
        let next = list[frameIndex % list.count]
        if view.currentImage !== next { view.currentImage = next }
        // Ride the head-bobble: shift overlays by this frame's anchor delta.
        if let alist = anchors[s], !alist.isEmpty {
            let a = alist[frameIndex % alist.count]
            view.overlayShift = CGVector(dx: (a.x - refAnchor.x) * 2,
                                         dy: (a.y - refAnchor.y) * 2)
        }
    }

    private func updateWindowPosition() {
        let origin = NSPoint(x: engine.x - Config.petSize / 2,
                             y: engine.y - Config.petSize / 2)
        if origin == lastOrigin { return }
        lastOrigin = origin
        window.setFrameOrigin(origin)
    }

    private func visibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
