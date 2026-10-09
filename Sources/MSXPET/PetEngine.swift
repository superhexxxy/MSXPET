// PetEngine: pure, testable game logic ported from xpet.c.
// Coordinates are AppKit-style: origin bottom-left, Y-up.
// All mutations go through update(dtMs:...) so behaviour is deterministic in tests.

import CoreGraphics
import Foundation

public struct PetEngine {
    // Position (subpixel for smooth Retina movement)
    public var x: CGFloat
    public var y: CGFloat
    public var targetX: CGFloat
    public var targetY: CGFloat

    public var state: PetState = .idle
    public var previousState: PetState = .idle

    // ms accumulators (mirror upstream long fields)
    public var wanderWaitMs: Int = 0
    public var frozenTimeMs: Int = 0
    public var unfreezeDelayMs: Int = 0
    public var happyTimeMs: Int = 0
    public var speechTimeMs: Int = 0

    // Laser-catch flash (swat state): like happy but short, with its own art.
    public var swatTimeMs: Int = 0

    public var chasing = false
    public var frozen = false
    public var dragging = false
    public var speech: String? = nil

    // One-shot sound request, raised at trigger points and consumed by Pet.
    public var soundCue: SoundEvent? = nil

    // Mood 0...100. Pets (clicks) raise it; neglect decays it. High mood =
    // zoomies, low mood = sleepy. Never shown as UI — only behaviour.
    public var mood: CGFloat = 70
    private var moodDecayAccumMs = 0

    // Day/night energy. hourOverride is a test seam (nil = system clock).
    public var hourOverride: Int? = nil

    // Drop physics (release with a fling → gravity + bounces).
    public var falling = false
    private var fallVelocity = CGVector(dx: 0, dy: 0)
    private var bounces = 0

    // Wall-cling: flung into an edge → scramble, slide, slip or (rarely)
    // recover. Sides + top only; the floor is for landing.
    public var clinging = false
    private enum ClingEdge { case left, right, top }
    private var clingEdge = ClingEdge.left
    private var clingTimeMs = 0
    private var clingDurationMs = 2000
    private var scramblePhase = 0

    // Social / play targeting: chase a point (cursor pounce or another pet)
    // for a while, then resume wandering. Uses the walk states — no new art.
    private var socialTarget: CGPoint? = nil
    private var socialUntilMs = 0
    private var playCooldownMs = 6000

    // Laser catch cooldown (per pet so a clowder doesn't spam in unison).
    private var catchCooldownMs = 0
    public var catchReady: Bool { catchCooldownMs <= 0 }

    // Stall watchdog: legs running but going nowhere (blocked target,
    // opposing forces, numerical limbo) → reroute instead of treadmill.
    private var stallAccumMs = 0
    private var stallAnchor = CGPoint(x: 0, y: 0)

    // Laser target override (manager sets mouse + formation offset per pet).
    // When chasing and set, the pet hunts this instead of the raw cursor.
    public var laserTarget: CGPoint? = nil

    // Monotonic engine clock (advanced by update).
    private var clockMs = 0

    // Solicitation: comes over asking for pats, waits, rewards pats.
    public var begging = false
    private var begUntilMs = 0
    private var begCooldownMs = 30_000
    // Zoomies: random short speed burst when feeling good.
    private var zoomieUntilMs = 0
    private var zoomieCooldownMs = 20_000
    // Ambient attention-seeking chatter (unprompted bubbles).
    private var ambientCooldownMs = 20_000
    // Awake purr (pat reward) — manager loops the purr sound while true.
    public private(set) var purring = false
    private var purrUntilMs = 0
    // Startle: fast cursor swoosh nearby → flinch + yelp (holds idle).
    private var prevMouse = CGPoint.zero
    private var prevMouseValid = false
    private var startleCooldownMs = 0
    // Grooming: idle spa breaks (happy flash + line, no click needed).
    private var groomCooldownMs = 40_000

    // Remember pre-drag state (upstream was_chasing / was_frozen)
    private var wasChasing = false
    private var wasFrozen = false

    // Grab offset in screen points (upstream drag_offset_x/y). Absolute
    // positioning: pet = mouseScreen - offset. Immune to event/timer
    // interleaving, unlike window-relative deltas.
    private var dragOffset = CGVector(dx: 0, dy: 0)

    // Octant flicker filter (see filteredDirection): candidate direction
    // must win this many consecutive ticks before the sprite switches.
    private static let directionPersistenceTicks = 6
    private var pendingDirection: PetState? = nil
    private var pendingTicks = 0

    public init(x: CGFloat, y: CGFloat) {
        self.x = x; self.y = y
        self.targetX = x; self.targetY = y
    }

    // MARK: - Octant (Y-up AppKit version of upstream find_octant)

    /// Upstream (X11, Y-down):
    ///   abs_dx > 2*abs_dy -> E/W ; abs_dy > 2*abs_dx -> S/N(+y=S) ;
    ///   else diagonals with dy<0 => north.
    /// AppKit (Y-up): flip dy sign — N = +y, S = -y.
    public static func findOctant(dx: CGFloat, dy: CGFloat) -> PetState {
        let ax = abs(dx), ay = abs(dy)
        if ax > ay * 2 { return dx > 0 ? .e : .w }
        if ay > ax * 2 { return dy > 0 ? .n : .s }
        if dx > 0 { return dy > 0 ? .ne : .se }
        return dy > 0 ? .nw : .sw
    }

    /// Normalised step vector for direction, scaled by speed*dt. Diagonal uses 1/sqrt(2).
    public static func stepVector(for direction: PetState, speed: CGFloat, dtSeconds: CGFloat) -> CGVector {
        let s = speed * dtSeconds
        let d = s * 0.7071067811865475
        switch direction {
        case .e: return CGVector(dx: s, dy: 0)
        case .w: return CGVector(dx: -s, dy: 0)
        case .n: return CGVector(dx: 0, dy: s)
        case .s: return CGVector(dx: 0, dy: -s)
        case .ne: return CGVector(dx: d, dy: d)
        case .se: return CGVector(dx: d, dy: -d)
        case .nw: return CGVector(dx: -d, dy: d)
        case .sw: return CGVector(dx: -d, dy: -d)
        default: return CGVector(dx: 0, dy: 0)
        }
    }

    // MARK: - Destination

    public mutating func pickRandomDestination(in rect: CGRect, margin: CGFloat, random: (ClosedRange<CGFloat>) -> CGFloat = { CGFloat.random(in: $0) }) {
        let minX = rect.minX + margin
        let minY = rect.minY + margin
        var maxX = rect.maxX - margin - Config.petSize
        var maxY = rect.maxY - margin - Config.petSize
        if maxX < minX { maxX = minX }
        if maxY < minY { maxY = minY }
        targetX = random(minX...maxX)
        targetY = random(minY...maxY)
        wanderWaitMs = 0
        // Zoomies: frisky pets sometimes just GO.
        if mood >= 50, zoomieCooldownMs <= 0, Double.random(in: 0...1) < 0.45 {
            zoomieUntilMs = clockMs + 1500
            zoomieCooldownMs = Int.random(in: 20_000...40_000)
            speech = "ZOOMIES!!"
            speechTimeMs = 0
        }
    }

    // MARK: - Interactions (mirror on_button_press/release, pet_* in xpet.c)

    /// Grab the pet. mouseScreen must be global AppKit screen coords
    /// (NSEvent.mouseLocation space — same space as x/y). Records the
    /// grab offset so dragTo() tracks 1:1, mirroring upstream's
    /// drag_offset + XQueryPointer absolute positioning.
    public mutating func beginDrag(mouseScreen: CGPoint) {
        wasChasing = chasing; wasFrozen = frozen
        dragging = true; frozen = true; chasing = false
        falling = false
        clinging = false
        dragOffset = CGVector(dx: mouseScreen.x - x, dy: mouseScreen.y - y)
        setState(.dragged)
        speech = ["hey!", "hup!", "heave-ho!"].randomElement()
        speechTimeMs = 0
        soundCue = .grab
    }

    /// Absolute move — exact regardless of event granularity or how far
    /// the cursor jumps between events.
    public mutating func dragTo(mouseScreen: CGPoint) {
        x = mouseScreen.x - dragOffset.dx
        y = mouseScreen.y - dragOffset.dy
        targetX = x; targetY = y
    }

    public mutating func endDrag(in rect: CGRect, releaseVelocity: CGVector = .zero) {
        dragging = false
        chasing = wasChasing
        targetX = x; targetY = y

        let flingSpeed = hypot(releaseVelocity.dx, releaseVelocity.dy)
        if flingSpeed > 350 {
            // FLUNG! Gravity takes over; the splayed dragged frames double
            // as the falling pose. Fun beats consistency: fresh start.
            falling = true
            bounces = 0
            frozen = false
            unfreezeDelayMs = 0
            fallVelocity = CGVector(
                dx: max(-900, min(900, releaseVelocity.dx)),
                dy: max(-900, min(900, releaseVelocity.dy))
            )
            setState(.dragged)
            return
        }

        frozen = wasFrozen
        unfreezeDelayMs = Config.unfreezeDelayMs
        if wasFrozen {
            setState(.idle); frozenTimeMs = 0
        } else if !wasChasing {
            pickRandomDestination(in: rect, margin: Config.wanderMargin)
            setState(.idle)
        } else {
            setState(.e)
        }
    }

    public mutating func toggleChase(in rect: CGRect) {
        let wasFrozenLocal = frozen
        let wasAsleep = state == .sleeping
        chasing.toggle()
        if chasing {
            frozen = false
            setState(wasFrozenLocal ? .idle : .e)
            if wasFrozenLocal { unfreezeDelayMs = Config.unfreezeDelayMs }
            speech = wasAsleep ? "nyawn… fine, I'M UP" : "can't catch me!"
            speechTimeMs = 0
            if wasAsleep { soundCue = .wake }
        } else {
            pickRandomDestination(in: rect, margin: Config.wanderMargin)
            setState(.idle)
        }
    }

    public mutating func toggleFreeze() {
        let wasAsleep = state == .sleeping
        frozen.toggle()
        if frozen { setState(.idle); frozenTimeMs = 0 }
        else {
            unfreezeDelayMs = Config.unfreezeDelayMs; setState(.idle)
            if wasAsleep { speech = "nyawn…"; speechTimeMs = 0; soundCue = .wake }
        }
    }

    public mutating func interact() {
        guard state != .happy else { return }
        previousState = state
        setState(.happy)
        happyTimeMs = 0
        if begging {
            // She came asking and you delivered: maximum reward.
            begging = false
            begCooldownMs = Int.random(in: 45_000...90_000)
            mood = min(100, mood + 20)
            purring = true
            purrUntilMs = clockMs + 5000
            speech = ["prrrp! ♥", "* LOUD purring *", "yessss. there."].randomElement()
            speechTimeMs = 0
            soundCue = .happy
            return
        }
        mood = min(100, mood + 12)
        if !Config.petPhrases.isEmpty {
            var phrase = Config.petPhrases.randomElement()!
            if mood >= 85 { phrase += " ♥" }
            speech = phrase
            speechTimeMs = 0
            soundCue = .happy
        }
    }

    // MARK: - Per-tick update (mirror run() loop)

    /// dtMs: elapsed ms since last tick. mouse: global mouse in AppKit coords.
    public mutating func update(dtMs: Int, mouse: CGPoint, visibleRect: CGRect) {
        clockMs += dtMs
        trackStartle(dtMs: dtMs, mouse: mouse)
        // speech expiry
        if speech != nil {
            speechTimeMs += dtMs
            if speechTimeMs >= Config.speechDurationMs { speech = nil; speechTimeMs = 0 }
        }
        // Neglect: mood decays slowly when nobody pets the creature.
        moodDecayAccumMs += dtMs
        if moodDecayAccumMs >= 10_000 {
            moodDecayAccumMs = 0
            mood = max(0, mood - 2)
        }
        if catchCooldownMs > 0 { catchCooldownMs -= dtMs }
        if zoomieCooldownMs > 0 { zoomieCooldownMs -= dtMs }
        if begCooldownMs > 0 { begCooldownMs -= dtMs }
        if ambientCooldownMs > 0 { ambientCooldownMs -= dtMs }
        purring = clockMs < purrUntilMs
        // Beg window expired while waiting for pats.
        if begging, clockMs >= begUntilMs {
            begging = false
            begCooldownMs = Int.random(in: 45_000...90_000)
            if Bool.random() {
                speech = Config.ignoredPhrases.randomElement()
                speechTimeMs = 0
            }
        }
        // happy + swat expiry. Both are MODAL flashes: while one is showing,
        // locomotion holds (fixes flashes being stomped one tick later by
        // moveToward, which made laser catches invisible).
        if state == .happy {
            happyTimeMs += dtMs
            if happyTimeMs >= Config.happyDurationMs { setState(previousState) }
            else { return }
        }
        if state == .swat {
            swatTimeMs += dtMs
            if swatTimeMs >= Config.swatDurationMs { setState(previousState) }
            else { return }
        }
        guard !dragging else { return }
        if falling {
            updateFall(dtMs: dtMs, visibleRect: visibleRect)
            return
        }

        if unfreezeDelayMs > 0 {
            unfreezeDelayMs -= dtMs
            if unfreezeDelayMs > 0 { setState(.idle); return }
            unfreezeDelayMs = 0
        }
        if frozen {
            frozenTimeMs += dtMs
            if frozenTimeMs >= sleepDelayMs(), state != .sleeping { setState(.sleeping) }
            return
        }
        if chasing {
            let t = laserTarget ?? mouse
            moveToward(tx: t.x, ty: t.y, dtSeconds: CGFloat(dtMs) / 1000.0, visibleRect: visibleRect)
        } else if let st = socialTarget {
            // Play chase (cursor pounce or another pet): dart at the point
            // for a while, then resume wandering.
            let dx = st.x - x, dy = st.y - y
            if clockMs >= socialUntilMs || dx * dx + dy * dy < 4.0 {
                socialTarget = nil
            } else {
                moveToward(tx: st.x, ty: st.y, dtSeconds: CGFloat(dtMs) / 1000.0, visibleRect: visibleRect)
            }
        } else {
            maybeAmbient()
            maybeGroom(dtMs: dtMs)
            maybeBeg(mouse: mouse, visibleRect: visibleRect)
            maybePounce(dtMs: dtMs, mouse: mouse)
            wander(dtMs: dtMs, dtSeconds: CGFloat(dtMs) / 1000.0, visibleRect: visibleRect)
        }
    }

    // MARK: - Attention seeking

    /// Unprompted bubbles while loitering: she talks even when unclicked.
    private mutating func maybeAmbient() {
        guard state == .idle, !begging, ambientCooldownMs <= 0 else { return }
        ambientCooldownMs = Int.random(in: 35_000...70_000)
        speech = Config.ambientPhrases.randomElement()
        speechTimeMs = 0
    }

    /// Comes over to the cursor asking for pats, sits, and waits.
    /// Click (pat) while begging → sits + purrs (see interact).
    private mutating func maybeBeg(mouse: CGPoint, visibleRect: CGRect) {
        guard state == .idle, !begging, socialTarget == nil,
              begCooldownMs <= 0 else { return }
        // Only when the cursor is actually reachable on this screen.
        let m = Config.wanderMargin
        guard mouse.x > visibleRect.minX + m, mouse.x < visibleRect.maxX - m,
              mouse.y > visibleRect.minY + m, mouse.y < visibleRect.maxY - m else { return }
        // Don't cross the whole world; only when she's already fairly near.
        let dx = mouse.x - x, dy = mouse.y - y
        guard dx * dx + dy * dy < 450 * 450 else { return }
        begging = true
        begUntilMs = clockMs + 9000
        socialTarget = mouse
        socialUntilMs = begUntilMs
        speech = Config.begPhrases.randomElement()
        speechTimeMs = 0
    }

    // MARK: - Drop physics

    private mutating func updateFall(dtMs: Int, visibleRect: CGRect) {
        if clinging {
            updateCling(dtMs: dtMs, visibleRect: visibleRect)
            return
        }
        let dtS = CGFloat(dtMs) / 1000.0
        fallVelocity.dy = max(-1400, fallVelocity.dy - 2200 * dtS)
        x += fallVelocity.dx * dtS
        y += fallVelocity.dy * dtS
        let floorY = visibleRect.minY + Config.petSize / 2
        let minX = visibleRect.minX + Config.petSize / 2
        let maxX = visibleRect.maxX - Config.petSize / 2
        let ceilY = visibleRect.maxY - Config.petSize / 2
        // Edge contact with inward speed → grab on (sides + top only).
        if x <= minX {
            x = minX
            if fallVelocity.dx < -150 { startCling(.left); return }
            fallVelocity.dx = 0
        } else if x >= maxX {
            x = maxX
            if fallVelocity.dx > 150 { startCling(.right); return }
            fallVelocity.dx = 0
        }
        if y <= floorY {
            y = floorY
            if abs(fallVelocity.dy) > 220, bounces < 2 {
                fallVelocity.dy = -fallVelocity.dy * 0.35
                fallVelocity.dx *= 0.5
                bounces += 1
            } else {
                land(in: visibleRect)
                return
            }
        }
        if y >= ceilY {
            y = ceilY
            if fallVelocity.dy > 150 { startCling(.top); return }
            fallVelocity.dy = 0
        }
        setState(.dragged) // splayed limbs double as the falling pose
    }

    private mutating func land(in visibleRect: CGRect) {
        falling = false
        clinging = false
        bounces = 0
        mood = min(100, mood + 5)
        pickRandomDestination(in: visibleRect, margin: Config.wanderMargin)
        setState(.idle)
        speech = "whee!"
        speechTimeMs = 0
        soundCue = .land
    }

    private mutating func startCling(_ edge: ClingEdge) {
        clinging = true
        clingEdge = edge
        clingTimeMs = 0
        scramblePhase = 0
        clingDurationMs = Int.random(in: 1500...2500)
        fallVelocity.dx = 0
        fallVelocity.dy = 0
        setState(edge == .top ? .clingTop : .clingSide)
        speech = "!"
        speechTimeMs = 0
        soundCue = .pounce
    }

    private mutating func updateCling(dtMs: Int, visibleRect: CGRect) {
        clingTimeMs += dtMs
        scramblePhase += dtMs
        let dtS = CGFloat(dtMs) / 1000.0
        let j: CGFloat = (scramblePhase / 120) % 2 == 0 ? 1 : -1
        let floorY = visibleRect.minY + Config.petSize / 2
        switch clingEdge {
        case .left:
            x = visibleRect.minX + Config.petSize / 2 + j
            // Grip fails over time: slides faster and faster.
            y -= (20 + 90 * CGFloat(clingTimeMs) / CGFloat(clingDurationMs)) * dtS
        case .right:
            x = visibleRect.maxX - Config.petSize / 2 + j
            y -= (20 + 90 * CGFloat(clingTimeMs) / CGFloat(clingDurationMs)) * dtS
        case .top:
            y = visibleRect.maxY - Config.petSize / 2
            x += j * 0.5 // dangling swing
        }
        setState(clingEdge == .top ? .clingTop : .clingSide)
        // Slid all the way down: that's a landing.
        if clingEdge != .top, y <= floorY {
            y = floorY
            land(in: visibleRect)
            return
        }
        guard clingTimeMs >= clingDurationMs else { return }
        if Double.random(in: 0...1) < 0.15 {
            // RARE RECOVERY: kicks off back into the room, still airborne.
            switch clingEdge {
            case .left: fallVelocity = CGVector(dx: 240, dy: 120)
            case .right: fallVelocity = CGVector(dx: -240, dy: 120)
            case .top: fallVelocity = CGVector(dx: Bool.random() ? 200 : -200, dy: 60)
            }
            clinging = false
            speech = "phew."
            speechTimeMs = 0
        } else {
            // Grip fails — gravity resumes next tick.
            clinging = false
        }
    }

    // MARK: - Awareness: startle, grooming

    /// Fast cursor swoosh nearby → startled flinch + yelp. Holds idle
    /// (no state change), so it never fights locomotion.
    private mutating func trackStartle(dtMs: Int, mouse: CGPoint) {
        defer {
            prevMouse = mouse
            prevMouseValid = true
        }
        if startleCooldownMs > 0 { startleCooldownMs -= dtMs }
        guard prevMouseValid, !dragging, !chasing, !falling, !frozen,
              state == .idle, socialTarget == nil else { return }
        let dtS = max(CGFloat(dtMs) / 1000.0, 0.001)
        let vx = (mouse.x - prevMouse.x) / dtS
        let vy = (mouse.y - prevMouse.y) / dtS
        guard hypot(vx, vy) > 2500 else { return }
        let dx = mouse.x - x, dy = mouse.y - y
        guard dx * dx + dy * dy < 120 * 120, startleCooldownMs <= 0 else { return }
        let d = max(1, hypot(dx, dy))
        x -= dx / d * 8
        y -= dy / d * 8
        targetX = x; targetY = y
        speech = ["whoa!", "EEP."].randomElement()
        speechTimeMs = 0
        soundCue = .pounce
        startleCooldownMs = 20_000
    }

    /// Idle spa break: brief happy grooming flash with a line.
    /// Yields the mic: never overwrites another fresh line.
    private mutating func maybeGroom(dtMs: Int) {
        if groomCooldownMs > 0 { groomCooldownMs -= dtMs }
        guard state == .idle, !begging, socialTarget == nil,
              groomCooldownMs <= 0, speech == nil else { return }
        groomCooldownMs = Int.random(in: 50_000...90_000)
        previousState = state
        setState(.happy)
        happyTimeMs = 0
        speech = Config.groomPhrases.randomElement()
        speechTimeMs = 0
    }

    // MARK: - Cursor pounce

    private mutating func maybePounce(dtMs: Int, mouse: CGPoint) {
        if playCooldownMs > 0 { playCooldownMs -= dtMs }
        guard state == .idle, playCooldownMs <= 0, socialTarget == nil else { return }
        let dx = mouse.x - x, dy = mouse.y - y
        guard dx * dx + dy * dy < 90 * 90 else { return }
        socialTarget = mouse
        socialUntilMs = clockMs + 700
        playCooldownMs = Int.random(in: 8_000...20_000)
        speech = "!"
        speechTimeMs = 0
        soundCue = .pounce
    }

    /// Laser catch! The pet bats the dot with its paws (swat frames),
    /// hops toward it, then resumes the hunt when the flash expires.
    public mutating func playCatch(toward point: CGPoint) {
        previousState = state.isWalking ? state : .e
        setState(.swat)
        swatTimeMs = 0
        let dx = point.x - x, dy = point.y - y
        let d = max(1, hypot(dx, dy))
        x += dx / d * 6
        y += dy / d * 6
        targetX = x; targetY = y
        mood = min(100, mood + 3)
        if Bool.random() { speech = "gotcha!"; speechTimeMs = 0 }
        soundCue = .happy
        catchCooldownMs = Int.random(in: 3000...6000)
    }

    /// Say an arbitrary line (dialogue system, greetings). Bubble +
    /// auto-show handled downstream; no state change.
    public mutating func say(_ line: String) {
        speech = line
        speechTimeMs = 0
    }

    /// Pet-pet greeting: mutual happy flash with a cute line.
    public mutating func greet() {        if state == .happy || state == .swat || dragging || falling
            || frozen || chasing || begging { return }
        previousState = state
        setState(.happy)
        happyTimeMs = 0
        speech = Config.greetPhrases.randomElement()
        speechTimeMs = 0
    }

    /// Another pet (or the manager) invites this one to chase a point.
    public mutating func inviteToChase(_ point: CGPoint, durationMs: Int) {
        socialTarget = point
        socialUntilMs = clockMs + durationMs
    }

    // MARK: - Mood + energy

    /// Combined speed multiplier: happy pets get zoomies, grumpy/sleepy
    /// pets (and late-night pets) slow down.
    private func speedMultiplier() -> CGFloat {
        let moodMult: CGFloat = mood >= 80 ? 1.35 : (mood <= 25 ? 0.8 : 1.0)
        let zoom: CGFloat = clockMs < zoomieUntilMs ? 1.9 : 1.0
        return min(2.0, moodMult * Self.energyMultiplier(hour: currentHour()) * zoom)
    }

    /// Night owls sleep: 23:00–06:00 sluggish, 07:00–10:00 zoomies.
    public static func energyMultiplier(hour: Int) -> CGFloat {
        if hour >= 23 || hour <= 6 { return 0.8 }
        if hour >= 7 && hour <= 10 { return 1.2 }
        return 1.0
    }

    private func currentHour() -> Int {
        if let h = hourOverride { return h }
        return Calendar.current.component(.hour, from: Date())
    }

    private func sleepDelayMs() -> Int {
        // Tired or low-mood pets doze off faster when frozen.
        if mood <= 25 || Self.energyMultiplier(hour: currentHour()) < 1.0 {
            return Config.sleepDelayMs / 2
        }
        return Config.sleepDelayMs
    }

    private mutating func wander(dtMs: Int, dtSeconds: CGFloat, visibleRect: CGRect) {
        let dx = targetX - x, dy = targetY - y
        if dx * dx + dy * dy < 4.0 { // arrived (matches upstream <4.0 dist²)
            if wanderWaitMs <= 0 {
                wanderWaitMs = Int.random(in: Config.wanderMinWaitMs...Config.wanderMaxWaitMs)
                setState(.idle)
            } else {
                wanderWaitMs -= dtMs
                if wanderWaitMs <= 0 { pickRandomDestination(in: visibleRect, margin: Config.wanderMargin) }
            }
            return
        }
        moveToward(tx: targetX, ty: targetY, dtSeconds: dtSeconds, visibleRect: visibleRect)
    }

    private mutating func moveToward(tx: CGFloat, ty: CGFloat, dtSeconds: CGFloat,
                                    visibleRect: CGRect) {
        let dx = tx - x, dy = ty - y
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist * dist < 4.0 {
            setState(.idle)
            stallAccumMs = 0
            stallAnchor = CGPoint(x: x, y: y)
            return
        }
        // Position follows the TRUE normalized vector (smooth). Upstream
        // stepped along the snapped octant, which at 60Hz re-evaluation
        // dithers E-step/NE-step every tick near a boundary (positional
        // micro-jitter on top of the sprite flicker).
        let maxStep = Config.petSpeedPointsPerSecond * speedMultiplier() * dtSeconds
        if dist <= maxStep + 0.5 { x = tx; y = ty }
        else { x += dx / dist * maxStep; y += dy / dist * maxStep }
        // Displayed sprite uses the hysteresis-filtered octant.
        setState(filteredDirection(Self.findOctant(dx: dx, dy: dy)))
        // Stall watchdog: walking visuals with no travel for 1.5s means
        // something is wrong (blocked, opposed, or numerical) — reroute
        // to a fresh destination instead of treadmilling forever.
        stallAccumMs += Int(dtSeconds * 1000)
        if stallAccumMs >= 1500 {
            let traveled = hypot(x - stallAnchor.x, y - stallAnchor.y)
            stallAccumMs = 0
            stallAnchor = CGPoint(x: x, y: y)
            if traveled < 6 {
                pickRandomDestination(in: visibleRect, margin: Config.wanderMargin)
                wanderWaitMs = 500
                setState(.idle)
                if Bool.random() {
                    speech = "hmm."
                    speechTimeMs = 0
                }
            }
        }
    }

    /// Octant flicker filter: at 60Hz, float noise near a boundary flips the
    /// raw octant near-every tick (measured 175 flips / 300 ticks), swapping
    /// sprites at full frame rate. A new walk direction must win N consecutive
    /// ticks before the sprite switches. Movement above always follows the
    /// true vector, so genuine turns only lag ~100ms — imperceptible.
    private mutating func filteredDirection(_ raw: PetState) -> PetState {
        guard state.isWalking else {
            pendingDirection = nil; pendingTicks = 0
            return raw
        }
        if raw == state { pendingDirection = nil; pendingTicks = 0; return raw }
        if pendingDirection == raw { pendingTicks += 1 }
        else { pendingDirection = raw; pendingTicks = 1 }
        if pendingTicks >= Self.directionPersistenceTicks {
            pendingDirection = nil; pendingTicks = 0
            return raw
        }
        return state
    }

    private mutating func setState(_ s: PetState) {
        // Upstream preserves walk-frame phase when switching between walk states;
        // frame handling lives in PetManager — here we just switch state.
        state = s
    }
}
