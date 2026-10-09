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

    public var chasing = false
    public var frozen = false
    public var dragging = false
    public var speech: String? = nil

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

    // Social / play targeting: chase a point (cursor pounce or another pet)
    // for a while, then resume wandering. Uses the walk states — no new art.
    private var socialTarget: CGPoint? = nil
    private var socialUntilMs = 0
    private var playCooldownMs = 6000

    // Laser target override (manager sets mouse + formation offset per pet).
    // When chasing and set, the pet hunts this instead of the raw cursor.
    public var laserTarget: CGPoint? = nil

    // Monotonic engine clock (advanced by update).
    private var clockMs = 0

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
        dragOffset = CGVector(dx: mouseScreen.x - x, dy: mouseScreen.y - y)
        setState(.dragged)
        speech = ["hey!", "hup!", "heave-ho!"].randomElement()
        speechTimeMs = 0
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
            if wasAsleep { speech = "nyawn…"; speechTimeMs = 0 }
        }
    }

    public mutating func interact() {
        guard state != .happy else { return }
        previousState = state
        setState(.happy)
        happyTimeMs = 0
        mood = min(100, mood + 12)
        if !Config.petPhrases.isEmpty {
            var phrase = Config.petPhrases.randomElement()!
            if mood >= 85 { phrase += " ♥" }
            speech = phrase
            speechTimeMs = 0
        }
    }

    // MARK: - Per-tick update (mirror run() loop)

    /// dtMs: elapsed ms since last tick. mouse: global mouse in AppKit coords.
    public mutating func update(dtMs: Int, mouse: CGPoint, visibleRect: CGRect) {
        clockMs += dtMs
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
        // happy expiry
        if state == .happy {
            happyTimeMs += dtMs
            if happyTimeMs >= Config.happyDurationMs { setState(previousState) }
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
            moveToward(tx: t.x, ty: t.y, dtSeconds: CGFloat(dtMs) / 1000.0)
        } else if let st = socialTarget {
            // Play chase (cursor pounce or another pet): dart at the point
            // for a while, then resume wandering.
            let dx = st.x - x, dy = st.y - y
            if clockMs >= socialUntilMs || dx * dx + dy * dy < 4.0 {
                socialTarget = nil
            } else {
                moveToward(tx: st.x, ty: st.y, dtSeconds: CGFloat(dtMs) / 1000.0)
            }
        } else {
            maybePounce(dtMs: dtMs, mouse: mouse)
            wander(dtMs: dtMs, dtSeconds: CGFloat(dtMs) / 1000.0, visibleRect: visibleRect)
        }
    }

    // MARK: - Drop physics

    private mutating func updateFall(dtMs: Int, visibleRect: CGRect) {
        let dtS = CGFloat(dtMs) / 1000.0
        fallVelocity.dy = max(-1400, fallVelocity.dy - 2200 * dtS)
        x += fallVelocity.dx * dtS
        y += fallVelocity.dy * dtS
        let floorY = visibleRect.minY + Config.petSize / 2
        let minX = visibleRect.minX + Config.petSize / 2
        let maxX = visibleRect.maxX - Config.petSize / 2
        x = min(max(x, minX), maxX)
        if y <= floorY {
            y = floorY
            if abs(fallVelocity.dy) > 220, bounces < 2 {
                fallVelocity.dy = -fallVelocity.dy * 0.35
                fallVelocity.dx *= 0.5
                bounces += 1
            } else {
                // Landed. That was fun.
                falling = false
                bounces = 0
                mood = min(100, mood + 5)
                pickRandomDestination(in: visibleRect, margin: Config.wanderMargin)
                setState(.idle)
                speech = "whee!"
                speechTimeMs = 0
                return
            }
        }
        if y > visibleRect.maxY - Config.petSize / 2 {
            y = visibleRect.maxY - Config.petSize / 2
            fallVelocity.dy = 0
        }
        setState(.dragged) // splayed limbs double as the falling pose
    }

    // MARK: - Cursor pounce

    private mutating func maybePounce(dtMs: Int, mouse: CGPoint) {
        if playCooldownMs > 0 { playCooldownMs -= dtMs }
        guard state == .idle, playCooldownMs <= 0 else { return }
        let dx = mouse.x - x, dy = mouse.y - y
        guard dx * dx + dy * dy < 90 * 90 else { return }
        socialTarget = mouse
        socialUntilMs = clockMs + 700
        playCooldownMs = Int.random(in: 8_000...20_000)
        speech = "!"
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
        return moodMult * Self.energyMultiplier(hour: currentHour())
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
        moveToward(tx: targetX, ty: targetY, dtSeconds: dtSeconds)
    }

    private mutating func moveToward(tx: CGFloat, ty: CGFloat, dtSeconds: CGFloat) {
        let dx = tx - x, dy = ty - y
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist * dist < 4.0 { setState(.idle); return }
        // Position follows the TRUE normalized vector (smooth). Upstream
        // stepped along the snapped octant, which at 60Hz re-evaluation
        // dithers E-step/NE-step every tick near a boundary (positional
        // micro-jitter on top of the sprite flicker).
        let maxStep = Config.petSpeedPointsPerSecond * speedMultiplier() * dtSeconds
        if dist <= maxStep + 0.5 { x = tx; y = ty }
        else { x += dx / dist * maxStep; y += dy / dist * maxStep }
        // Displayed sprite uses the hysteresis-filtered octant.
        setState(filteredDirection(Self.findOctant(dx: dx, dy: dy)))
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
