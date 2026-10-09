// PetManager: owns the clowder — N pets, one shared timer in the fastest
// needed gear, the laser dot, and power management (pause while locked).

import AppKit
import Foundation

public final class PetManager {
    private var pets: [Pet] = []
    private let laser = LaserDot()
    private let sound = SoundManager()
    private var timer: Timer?
    private var lastTick = Date()
    private var currentInterval: TimeInterval = Config.tickInterval
    private var systemPaused = false
    private var playCheckAccumMs = 0
    private var dialogue = DialogueRunner()
    private var dialogueCooldownMs = 30_000

    // Shared asset cache so 3 nekos don't triple image memory.
    // Anchors ride alongside frames for overlay head-tracking.
    private struct PetAssets {
        var frames: [PetState: [NSImage]]
        var anchors: [PetState: [CGPoint]] // per-frame topmost (bobble deltas)
        var ref: CGPoint
    }
    private var assetCache: [String: PetAssets] = [:]

    // Accessories (overlay layers). User-enabled set persisted.
    private var allOverlays: [Overlay] = []
    private var enabledOverlays: Set<String> = []

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
        allOverlays = OverlayLoader.loadAll()
        enabledOverlays = Set(UserDefaults.standard.stringArray(forKey: Config.accessoriesKey) ?? [])
        spawnPets(count: count)
        if laserOn {
            for (i, p) in pets.enumerated() {
                p.engine.chasing = true
                p.laserPhase = CGFloat(i) / CGFloat(max(1, pets.count)) * 2 * .pi
            }
        }
        pets.first?.engine.speech =
            "hi! i'm \(UserDefaults.standard.string(forKey: Config.nameKey) ?? petName)!"
        pets.first?.engine.speechTimeMs = 0
        subscribePowerNotifications()
        startLoop()
    }

    // MARK: - Clowder management

    private func assets(for name: String) -> PetAssets {
        if let cached = assetCache[name] { return cached }
        var frames: [PetState: [NSImage]] = [:]
        var anchors: [PetState: [CGPoint]] = [:]
        var real: Set<PetState> = []
        for s in PetState.allCases {
            let loaded = AnimationLoader.loadFrames(petName: name, state: s)
            if loaded.isEmpty { continue } // resolved below: fallback, else placeholder
            real.insert(s)
            frames[s] = loaded
            anchors[s] = loaded.map { HeadAnchor.of($0) }
        }
        // Same-pet fallbacks (swat→happy, clings→dragged) so new poses
        // degrade to the closest real art instead of placeholders.
        for s in PetState.allCases where !real.contains(s) {
            if let fb = s.fallbackState, real.contains(fb) {
                frames[s] = frames[fb]
                anchors[s] = anchors[fb]
                real.insert(s)
            } else {
                let ph = AnimationLoader.placeholderFrames(for: s, size: Config.petSize)
                frames[s] = ph
                anchors[s] = ph.map { HeadAnchor.of($0) }
            }
        }
        let ref = anchors[.idle]?.first ?? CGPoint(x: 16, y: 4)
        let assets = PetAssets(frames: frames, anchors: anchors, ref: ref)
        assetCache[name] = assets
        return assets
    }

    private func spawnPets(count: Int) {
        let v = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let origins = [CGPoint(x: v.midX, y: v.midY),
                       CGPoint(x: v.midX - 120, y: v.midY + 60),
                       CGPoint(x: v.midX + 120, y: v.midY - 60)]
        let a = assets(for: petName)
        for i in 0..<count {
            let pet = Pet(petName: petName, assets: (a.frames, a.anchors, a.ref), at: origins[i])
            pet.soundHandler = { [weak self] cue in self?.sound.play(cue) }
            pets.append(pet)
        }
    }

    public func setCount(_ count: Int) {
        let n = max(1, min(3, count))
        UserDefaults.standard.set(n, forKey: Config.countKey)
        for p in pets { p.close() }
        pets = []
        spawnPets(count: n)
        if laserOn {
            for (i, p) in pets.enumerated() {
                p.engine.chasing = true
                p.laserPhase = CGFloat(i) / CGFloat(max(1, pets.count)) * 2 * .pi
            }
        }
        poke()
    }

    public func switchPet(_ name: String) {
        petName = name
        UserDefaults.standard.set(name, forKey: Config.selectedPetKey)
        let a = assets(for: name)
        for p in pets { p.setFrames(a.frames, anchors: a.anchors, ref: a.ref, petName: name) }
        poke()
    }

    // MARK: - Accessories

    public func overlayList() -> [(name: String, enabled: Bool)] {
        allOverlays.map { ($0.name, enabledOverlays.contains($0.name)) }
    }

    public func setOverlay(_ name: String, on: Bool) {
        if on { enabledOverlays.insert(name) } else { enabledOverlays.remove(name) }
        UserDefaults.standard.set(Array(enabledOverlays), forKey: Config.accessoriesKey)
        poke()
    }

    public func reloadOverlays() {
        allOverlays = OverlayLoader.loadAll()
        poke()
    }

    private func activeOverlays() -> [Overlay] {
        allOverlays.filter { enabledOverlays.contains($0.name) }
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

    /// Snack time! Feeds the whole clowder (wakes sleepers — food > sleep).
    public func feed() {
        for p in pets {
            p.engine.feed()
            p.showBubbleIfNew()
        }
        poke()
    }

    /// Display name for menus/tags: custom name or species, numbered in a pack.
    public func displayName(for index: Int) -> String {
        let base = UserDefaults.standard.string(forKey: Config.nameKey) ?? petName.capitalized
        return pets.count > 1 ? "\(base) #\(index + 1)" : base
    }

    /// (name, mood 0-100) per pet, for the Mood menu.
    public func moods() -> [(String, Int)] {
        pets.enumerated().map { (displayName(for: $0), Int($1.engine.mood)) }
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
        sound.play(on ? .laserOn : .laserOff)
        if on {
            for (i, p) in pets.enumerated() {
                p.laserPhase = CGFloat(i) / CGFloat(max(1, pets.count)) * 2 * .pi
            }
        }
        poke()
    }

    // MARK: - Sound

    public var soundEnabled: Bool { sound.enabled }

    public func setSound(_ on: Bool) {
        sound.enabled = on
        if !on { sound.stopAll() }
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
            sound.setPurr(false) // no purring to an empty locked room
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
            let dtS = CGFloat(dtMs) / 1000.0
            for (i, p) in pets.enumerated() {
                p.engine.chasing = true
                p.engine.frozen = false
                // Ring only rotates while far: near the dot the target
                // steadies so the pet can close in and catch it.
                let mdx = mouse.x - p.engine.x, mdy = mouse.y - p.engine.y
                if mdx * mdx + mdy * mdy > 60 * 60 {
                    p.laserPhase += dtS * 0.9
                }
                let off = LaserFormation.offset(index: i, count: pets.count,
                                                timeSeconds: p.laserPhase)
                let target = CGPoint(x: mouse.x + off.dx, y: mouse.y + off.dy)
                p.engine.laserTarget = target
                // Caught it! Bat the dot, celebrate, resume the hunt.
                let dx = target.x - p.engine.x, dy = target.y - p.engine.y
                if dx * dx + dy * dy < 24 * 24, p.engine.catchReady {
                    p.engine.playCatch(toward: target)
                }
            }
        } else {
            for p in pets { p.engine.laserTarget = nil }
        }
        separatePets()
        let overlays = activeOverlays()
        for (i, p) in pets.enumerated() {
            p.tick(dtMs: dtMs, mouse: mouse, visibleRect: visible)
            p.applyOverlays(p.engine.state == .sleeping || p.engine.clinging ? [] : overlays)
            p.updateTag(show: pets.count >= 2, name: displayName(for: i),
                        visibleRect: visible)
        }
        // Deliver due dialogue lines.
        for (idx, line) in dialogue.update(dtMs: dtMs) {
            if pets.indices.contains(idx) { pets[idx].engine.say(line) }
        }
        // Sleep purr + pat purr: one shared loop while ANY pet dozes
        // or luxuriates (idempotent).
        sound.setPurr(pets.contains {
            $0.engine.state == .sleeping || $0.engine.purring
        })
        maybeSocialPlay(dtMs: dtMs)
        let want = desiredInterval()
        if abs(want - currentInterval) > 0.001, !systemPaused {
            timer?.invalidate()
            startLoop()
        }
    }

    /// Soft separation so pets never sit on the same pixel (laser packs
    /// especially). Applied pre-tick; engines re-aim next frame.
    private func separatePets() {
        for i in 0..<pets.count {
            for j in (i + 1)..<pets.count {
                let a = CGPoint(x: pets[i].engine.x, y: pets[i].engine.y)
                let b = CGPoint(x: pets[j].engine.x, y: pets[j].engine.y)
                let (na, nb) = Separation.push(a: a, b: b)
                pets[i].engine.x += na.dx; pets[i].engine.y += na.dy
                pets[j].engine.x += nb.dx; pets[j].engine.y += nb.dy
            }
        }
    }

    /// Pet-pet play: occasionally one kitten chases another's position,
    /// close ones stop to say hi, and idle pairs start little dialogues.
    private func maybeSocialPlay(dtMs: Int) {
        guard pets.count >= 2 else { return }
        playCheckAccumMs += dtMs
        guard playCheckAccumMs >= 2000 else { return }
        playCheckAccumMs = 0
        if dialogueCooldownMs > 0 { dialogueCooldownMs -= 2000 }
        // Greetings first: mutual happy flash when snouts nearly touch.
        for i in 0..<pets.count {
            for j in (i + 1)..<pets.count {
                let dx = pets[i].engine.x - pets[j].engine.x
                let dy = pets[i].engine.y - pets[j].engine.y
                if dx * dx + dy * dy < 70 * 70 {
                    if Double.random(in: 0...1) < 0.3 {
                        pets[i].engine.greet()
                        pets[j].engine.greet()
                        return
                    }
                    // …otherwise, if both are just hanging around, talk.
                    if !dialogue.isRunning, dialogueCooldownMs <= 0,
                       bothLoitering(pets[i], pets[j]),
                       Double.random(in: 0...1) < 0.5 {
                        dialogue.start(participants: [i, j])
                        dialogueCooldownMs = Int.random(in: 45_000...75_000)
                        return
                    }
                }
            }
        }
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

    /// A dialogue pair: both calm, wandering or idling, unbothered.
    private func bothLoitering(_ a: Pet, _ b: Pet) -> Bool {
        for p in [a, b] {
            let e = p.engine
            if e.dragging || e.falling || e.clinging || e.chasing || e.frozen { return false }
            if e.state == .sleeping || e.state == .happy || e.state == .swat { return false }
        }
        return true
    }

    private func visibleFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
