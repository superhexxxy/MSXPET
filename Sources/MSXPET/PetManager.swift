// PetManager: owns engine + windows + 60Hz loop + frame animation.
// Frame timing mirrors upstream FRAME_DURATION (200ms) with walk-phase
// preservation handled implicitly by not resetting on walk->walk switches.

import AppKit
import Foundation

public final class PetManager {
    private let window: PetWindow
    private let view: PetView
    private let bubble = SpeechBubble()
    private var engine: PetEngine
    private var timer: Timer?
    private var lastTick = Date()

    private var frames: [PetState: [NSImage]] = [:]
    private var frameIndex = 0
    private var frameAccumMs = 0
    private var lastState: PetState = .idle

    public private(set) var petName: String

    public init(petName: String = Config.petName) {
        self.petName = petName
        let size = Config.petSize
        engine = PetEngine(x: 400, y: 300)
        window = PetWindow(contentRect: NSRect(x: 400, y: 300, width: size, height: size))
        view = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.autoresizingMask = [.width, .height]
        window.contentView = view

        loadFrames()

        if let screen = NSScreen.main {
            let v = screen.visibleFrame
            engine = PetEngine(x: v.midX, y: v.midY)
            engine.pickRandomDestination(in: v, margin: Config.wanderMargin)
        }

        view.onDrag = { [weak self] dx, dy in self?.handleDrag(dx: dx, dy: dy) }
        view.onDragEnd = { [weak self] in self?.handleDragEnd() }
        view.onClick = { [weak self] in self?.handleClick() }

        updateWindowPosition()
        window.orderFrontRegardless()
        startLoop()
    }

    public func switchPet(_ name: String) {
        petName = name
        UserDefaults.standard.set(name, forKey: Config.selectedPetKey)
        loadFrames()
        frameIndex = 0; frameAccumMs = 0
    }

    private func loadFrames() {
        for s in PetState.allCases {
            let loaded = AnimationLoader.loadFrames(petName: petName, state: s)
            frames[s] = loaded.isEmpty
                ? AnimationLoader.placeholderFrames(for: s, size: Config.petSize)
                : loaded
        }
    }

    // MARK: - Input

    private func handleDrag(dx: CGFloat, dy: CGFloat) {
        if !engine.dragging { engine.beginDrag() }
        // PetView reports view-space delta (y-down); convert to screen (y-up).
        engine.dragBy(dx: dx, dy: -dy)
        bubble.hide()
    }

    private func handleDragEnd() {
        engine.endDrag(in: visibleFrame())
    }

    private func handleClick() {
        engine.interact()
        if let text = engine.speech {
            bubble.show(text: text, above: window.frame.origin,
                        petSize: Config.petSize, visibleRect: visibleFrame())
        }
    }

    public func toggleChase() { engine.toggleChase(in: visibleFrame()) }
    public func toggleFreeze() { engine.toggleFreeze() }

    // MARK: - Loop

    private func startLoop() {
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: Config.tickInterval, repeats: true) { [weak self] _ in self?.tick() }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    private func tick() {
        let now = Date()
        let dtMs = max(1, Int(now.timeIntervalSince(lastTick) * 1000))
        lastTick = now
        let mouse = NSEvent.mouseLocation
        engine.update(dtMs: min(dtMs, 100), mouse: mouse, visibleRect: visibleFrame())
        updateAnimation(dtMs: dtMs)
        updateWindowPosition()
    }

    private func updateAnimation(dtMs: Int) {
        let s = engine.state
        if s != lastState {
            // Preserve walk phase like upstream set_pet_state walk->walk path.
            if !(s.isWalking && lastState.isWalking) { frameIndex = 0; frameAccumMs = 0 }
            lastState = s
        }
        guard let list = frames[s], !list.isEmpty else { return }
        frameAccumMs += dtMs
        if frameAccumMs >= Config.frameDurationMs {
            frameAccumMs = 0
            frameIndex += 1
            if frameIndex >= list.count { frameIndex = 0 } // all upstream anims loop
        }
        view.currentImage = list[frameIndex % list.count]
    }

    private func updateWindowPosition() {
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: engine.x - size.width / 2,
                                      y: engine.y - size.height / 2))
    }

    private func visibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
