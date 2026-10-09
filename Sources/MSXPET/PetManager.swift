// PetManager: owns engine + windows + adaptive loop + frame animation.
// Frame timing mirrors upstream FRAME_DURATION (200ms) with walk-phase
// preservation handled implicitly by not resetting on walk->walk switches.

import AppKit
import Foundation

public final class PetManager {
    private let window: PetWindow
    private let view: PetView
    private let bubble = SpeechBubble()
    private let laser = LaserDot()
    private var engine: PetEngine
    private var timer: Timer?
    private var lastTick = Date()
    private var currentInterval: TimeInterval = Config.tickInterval
    private var systemPaused = false
    private var zzz = ZzzField()
    private var lastBubbleText: String?
    private var recentMoves: [(CGPoint, Date)] = []

    private var frames: [PetState: [NSImage]] = [:]
    private var frameIndex = 0
    private var frameAccumMs = 0
    private var lastState: PetState = .idle

    public private(set) var petName: String
    public private(set) var laserOn: Bool = false

    /// Battery saver: fast loop only while something moves; slow otherwise.
    /// Pure function of activity — unit-tested.
    public static func tickInterval(walking: Bool, chasing: Bool, dragging: Bool,
                                    falling: Bool, sleeping: Bool) -> TimeInterval {
        if dragging || falling || chasing || walking { return 1.0 / 60.0 }
        if sleeping { return 1.0 }
        return 0.1
    }

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

        view.onDragStart = { [weak self] pt in self?.handleDragStart(screen: pt) }
        view.onDragMove = { [weak self] pt in self?.handleDragMove(screen: pt) }
        view.onDragEnd = { [weak self] in self?.handleDragEnd() }
        view.onClick = { [weak self] in self?.handleClick() }

        laserOn = UserDefaults.standard.bool(forKey: Config.laserKey)
        if laserOn { engine.chasing = true }
        greet()

        updateWindowPosition()
        window.orderFrontRegardless()
        subscribePowerNotifications()
        startLoop()
    }

    private func greet() {
        let name = UserDefaults.standard.string(forKey: Config.nameKey) ?? petName
        engine.speech = "hi! i'm \(name)!"
        engine.speechTimeMs = 0
    }

    public func switchPet(_ name: String) {
        petName = name
        UserDefaults.standard.set(name, forKey: Config.selectedPetKey)
        loadFrames()
        frameIndex = 0; frameAccumMs = 0
        poke()
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
        updateWindowPosition() // sync now — zero frames of follow lag
    }

    private func handleDragEnd() {
        engine.endDrag(in: visibleFrame(), releaseVelocity: releaseVelocity())
        recentMoves = []
        poke() // falling anim starts immediately, no slow-tick lag
    }

    /// Release velocity from recent drag motion (pt/s), for fling-to-fall.
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
        poke()
    }

    private func showBubbleIfNew() {
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

    public func toggleChase() { engine.toggleChase(in: visibleFrame()); poke() }
    public func toggleFreeze() { engine.toggleFreeze(); poke() }

    public func setLaser(_ on: Bool) {
        laserOn = on
        UserDefaults.standard.set(on, forKey: Config.laserKey)
        if on {
            engine.frozen = false
            engine.chasing = true
            engine.speech = "ooh! shiny!"
            engine.speechTimeMs = 0
        } else {
            laser.hide()
            engine.chasing = false
            engine.pickRandomDestination(in: visibleFrame(), margin: Config.wanderMargin)
        }
        poke()
    }

    // MARK: - Power: pause while locked/asleep (zero CPU while away)

    private func subscribePowerNotifications() {
        let ws = NSWorkspace.shared
        ws.notificationCenter.addObserver(self, selector: #selector(sysPause),
                                         name: NSWorkspace.willSleepNotification, object: nil)
        ws.notificationCenter.addObserver(self, selector: #selector(sysResume),
                                         name: NSWorkspace.didWakeNotification, object: nil)
        let dist = DistributedNotificationCenter.default()
        dist.addObserver(self, selector: #selector(sysPause),
                         name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dist.addObserver(self, selector: #selector(sysResume),
                         name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func sysPause() { applySystemPause(true) }
    @objc private func sysResume() { applySystemPause(false) }

    func applySystemPause(_ paused: Bool) {
        if paused == systemPaused { return }
        systemPaused = paused
        if paused {
            timer?.invalidate(); timer = nil
        } else {
            lastTick = Date()
            startLoop()
            tick()
        }
    }

    // MARK: - Loop

    private func startLoop() {
        lastTick = Date()
        // Single registration in .common modes (fires during event tracking
        // too). NOTE: don't use scheduledTimer + add(.common) — that registers
        // the timer twice and risks double ticks.
        currentInterval = desiredInterval()
        let t = Timer(timeInterval: currentInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func desiredInterval() -> TimeInterval {
        Self.tickInterval(walking: engine.state.isWalking,
                          chasing: engine.chasing,
                          dragging: engine.dragging,
                          falling: engine.falling,
                          sleeping: engine.state == .sleeping)
    }

    /// Run a tick right now (user actions shouldn't wait for a slow tick).
    private func poke() {
        if !systemPaused { tick() }
    }

    private func tick() {
        if systemPaused { return }
        let now = Date()
        let dtMs = min(max(1, Int(now.timeIntervalSince(lastTick) * 1000)), 2000)
        lastTick = now
        let mouse = NSEvent.mouseLocation
        if laserOn {
            laser.move(to: mouse)
            engine.chasing = true
            engine.frozen = false
        }
        engine.update(dtMs: dtMs, mouse: mouse, visibleRect: visibleFrame())
        showBubbleIfNew()
        zzz.update(dtMs: dtMs, active: engine.state == .sleeping)
        view.zzz = zzz.parts
        updateAnimation(dtMs: dtMs)
        updateWindowPosition()
        // Settle the timer into the right gear.
        let want = desiredInterval()
        if abs(want - currentInterval) > 0.001, !systemPaused {
            timer?.invalidate()
            startLoop()
        }
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
        // Skip redundant assignment: the setter re-rasterizes the alpha mask
        // and forces a redraw on every call, even for the identical image.
        let next = list[frameIndex % list.count]
        if view.currentImage !== next { view.currentImage = next }
    }

    private var lastOrigin = NSPoint(x: -1, y: -1)

    private func updateWindowPosition() {
        let size = window.frame.size
        let origin = NSPoint(x: engine.x - size.width / 2,
                             y: engine.y - size.height / 2)
        // setFrameOrigin recomposites through the window server every call —
        // skip it when the pet hasn't moved (the common idle case).
        if origin == lastOrigin { return }
        lastOrigin = origin
        window.setFrameOrigin(origin)
    }

    private func visibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
