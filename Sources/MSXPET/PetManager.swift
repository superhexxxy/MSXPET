// PetManager: owns the clowder — N pets, one shared timer in the fastest
// needed gear, the laser dot, and power management (pause while locked).

import AppKit
import Foundation

public final class PetManager {
    private var pets: [Pet] = []
    private let laser = LaserDot()
    private var timer: Timer?
    private var lastTick = Date()
    private var currentInterval: TimeInterval = Config.tickInterval
    private var systemPaused = false
    private var playCheckAccumMs = 0

    // Shared frame cache so 3 nekos don't triple image memory.
    private var frameCache: [String: [PetState: [NSImage]]] = [:]

    public private(set) var petName: String
    public private(set) var laserOn: Bool = false
    public var petCount: Int { pets.count }

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
        let count = max(1, min(3, UserDefaults.standard.integer(forKey: Config.countKey) == 0
            ? 1 : UserDefaults.standard.integer(forKey: Config.countKey)))
        laserOn = UserDefaults.standard.bool(forKey: Config.laserKey)
        spawnPets(count: count)
        if laserOn {
            for p in pets { p.engine.chasing = true }
        }
        pets.first?.engine.speech =
            "hi! i'm \(UserDefaults.standard.string(forKey: Config.nameKey) ?? petName)!"
        pets.first?.engine.speechTimeMs = 0
        subscribePowerNotifications()
        startLoop()
    }

    // MARK: - Clowder management

    private func frames(for name: String) -> [PetState: [NSImage]] {
        if let cached = frameCache[name] { return cached }
        var dict: [PetState: [NSImage]] = [:]
        for s in PetState.allCases {
            let loaded = AnimationLoader.loadFrames(petName: name, state: s)
            dict[s] = loaded.isEmpty
                ? AnimationLoader.placeholderFrames(for: s, size: Config.petSize)
                : loaded
        }
        frameCache[name] = dict
        return dict
    }

    private func spawnPets(count: Int) {
        let v = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let origins = [CGPoint(x: v.midX, y: v.midY),
                       CGPoint(x: v.midX - 120, y: v.midY + 60),
                       CGPoint(x: v.midX + 120, y: v.midY - 60)]
        for i in 0..<count {
            pets.append(Pet(petName: petName, frames: frames(for: petName), at: origins[i]))
        }
    }

    public func setCount(_ count: Int) {
        let n = max(1, min(3, count))
        UserDefaults.standard.set(n, forKey: Config.countKey)
        for p in pets { p.close() }
        pets = []
        spawnPets(count: n)
        if laserOn { for p in pets { p.engine.chasing = true } }
        poke()
    }

    public func switchPet(_ name: String) {
        petName = name
        UserDefaults.standard.set(name, forKey: Config.selectedPetKey)
        let f = frames(for: name)
        for p in pets { p.setFrames(f, petName: name) }
        poke()
    }

    // MARK: - Shared actions (chaos applies to everyone)

    public func toggleChase() {
        for p in pets { p.engine.toggleChase(in: visibleFrame()) }
        poke()
    }

    public func toggleFreeze() {
        for p in pets { p.engine.toggleFreeze() }
        poke()
    }

    public func setLaser(_ on: Bool) {
        laserOn = on
        UserDefaults.standard.set(on, forKey: Config.laserKey)
        for p in pets {
            if on {
                p.engine.frozen = false
                p.engine.chasing = true
                p.engine.speech = "ooh! shiny!"
                p.engine.speechTimeMs = 0
            } else {
                p.engine.chasing = false
                p.engine.pickRandomDestination(in: visibleFrame(), margin: Config.wanderMargin)
            }
        }
        if !on { laser.hide() }
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

    // MARK: - Loop (one timer, fastest gear any pet needs)

    private func startLoop() {
        lastTick = Date()
        currentInterval = desiredInterval()
        let t = Timer(timeInterval: currentInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func desiredInterval() -> TimeInterval {
        var walking = false, chasing = false, dragging = false,
            falling = false, allSleeping = !pets.isEmpty
        for p in pets {
            walking = walking || p.engine.state.isWalking
            chasing = chasing || p.engine.chasing
            dragging = dragging || p.engine.dragging
            falling = falling || p.engine.falling
            allSleeping = allSleeping && p.engine.state == .sleeping
        }
        return Self.tickInterval(walking: walking, chasing: chasing,
                                 dragging: dragging, falling: falling,
                                 sleeping: allSleeping)
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
        let visible = visibleFrame()
        if laserOn {
            laser.move(to: mouse)
            for p in pets { p.engine.chasing = true; p.engine.frozen = false }
        }
        for p in pets { p.tick(dtMs: dtMs, mouse: mouse, visibleRect: visible) }
        maybeSocialPlay(dtMs: dtMs)
        let want = desiredInterval()
        if abs(want - currentInterval) > 0.001, !systemPaused {
            timer?.invalidate()
            startLoop()
        }
    }

    /// Pet-pet play: occasionally one kitten chases another's position.
    private func maybeSocialPlay(dtMs: Int) {
        guard pets.count >= 2 else { return }
        playCheckAccumMs += dtMs
        guard playCheckAccumMs >= 2000 else { return }
        playCheckAccumMs = 0
        guard Double.random(in: 0...1) < 0.12 else { return }
        let a = pets.randomElement()!
        let others = pets.filter { $0 !== a }
        guard let b = others.randomElement() else { return }
        let ok = !a.engine.dragging && !a.engine.falling && !a.engine.chasing
            && !a.engine.frozen && a.engine.state != .sleeping
        if ok {
            a.engine.inviteToChase(CGPoint(x: b.engine.x, y: b.engine.y), durationMs: 4000)
        }
    }

    private func visibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
