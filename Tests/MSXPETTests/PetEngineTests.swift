import XCTest
@testable import MSXPET

final class PetEngineTests: XCTestCase {
    func testFindOctantCardinalsYUp() {
        // AppKit Y-up: +y = north, -y = south (flipped vs upstream X11)
        XCTAssertEqual(PetEngine.findOctant(dx: 10, dy: 0), .e)
        XCTAssertEqual(PetEngine.findOctant(dx: -10, dy: 0), .w)
        XCTAssertEqual(PetEngine.findOctant(dx: 0, dy: 10), .n)
        XCTAssertEqual(PetEngine.findOctant(dx: 0, dy: -10), .s)
    }

    func testFindOctantDiagonals() {
        XCTAssertEqual(PetEngine.findOctant(dx: 5, dy: 5), .ne)
        XCTAssertEqual(PetEngine.findOctant(dx: 5, dy: -5), .se)
        XCTAssertEqual(PetEngine.findOctant(dx: -5, dy: 5), .nw)
        XCTAssertEqual(PetEngine.findOctant(dx: -5, dy: -5), .sw)
    }

    func testFindOctantStrongAxisThreshold() {
        // Upstream uses 2x threshold (not Qwen's /2)
        XCTAssertEqual(PetEngine.findOctant(dx: 10, dy: 4), .e)
        XCTAssertEqual(PetEngine.findOctant(dx: 4, dy: 10), .n)
    }

    func testStepVectorDiagonalNormalization() {
        let v = PetEngine.stepVector(for: .ne, speed: 100, dtSeconds: 1.0)
        XCTAssertEqual(v.dx, 70.71, accuracy: 0.1)
        XCTAssertEqual(v.dy, 70.71, accuracy: 0.1)
    }

    func testPickRandomDestinationClamped() {
        var e = PetEngine(x: 0, y: 0)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        e.pickRandomDestination(in: rect, margin: 100) { $0.lowerBound }
        XCTAssertGreaterThanOrEqual(e.targetX, 100)
        XCTAssertGreaterThanOrEqual(e.targetY, 100)
    }

    func testDragRoundTrip() {
        var e = PetEngine(x: 100, y: 100)
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 800)
        e.beginDrag(mouseScreen: CGPoint(x: 110, y: 120)) // grab 10,20 into the pet
        XCTAssertEqual(e.state, .dragged)
        e.dragTo(mouseScreen: CGPoint(x: 200, y: 300))
        XCTAssertEqual(e.x, 190, accuracy: 0.001)
        XCTAssertEqual(e.y, 280, accuracy: 0.001)
        e.endDrag(in: rect)
        XCTAssertEqual(e.state, .idle)
        XCTAssertFalse(e.dragging)
    }

    func testDragTracksExactlyOverDistantJumps() {
        // Regression: window-relative deltas fell behind the cursor
        // (emulated 620pt gap after a 1s fast pull). Absolute positioning
        // is exact no matter how coarse the events are.
        var e = PetEngine(x: 100, y: 100)
        e.beginDrag(mouseScreen: CGPoint(x: 100, y: 100))
        var mouse = CGPoint(x: 100, y: 100)
        for _ in 0..<125 { // 1s of 125pt jumps — brutal event starvation
            mouse.x += 125; mouse.y += 40
            e.dragTo(mouseScreen: mouse)
        }
        XCTAssertEqual(e.x, mouse.x, accuracy: 0.001)
        XCTAssertEqual(e.y, mouse.y, accuracy: 0.001)
    }

    func testChaseMovesTowardMouse() {
        var e = PetEngine(x: 0, y: 0)
        e.chasing = true
        let rect = CGRect(x: -1000, y: -1000, width: 3000, height: 3000)
        e.update(dtMs: 200, mouse: CGPoint(x: 500, y: 0), visibleRect: rect)
        XCTAssertGreaterThan(e.x, 0)
        XCTAssertEqual(e.state, .e)
    }

    func testBoundaryDirectionDoesNotFlicker() {
        // Regression: raw octant near the E/NE 2x boundary flipped
        // 175x / 300 ticks at 60Hz, swapping sprites at full frame rate.
        // Displayed state must stay put; position still converges.
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 800; e.targetY = 640
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var flips = 0
        var prev = e.state
        for _ in 0..<300 {
            e.update(dtMs: 16, mouse: CGPoint(x: 0, y: 0), visibleRect: rect)
            if e.state != prev, e.state.isWalking, prev.isWalking { flips += 1 }
            prev = e.state
        }
        XCTAssertLessThanOrEqual(flips, 4, "walk-direction flips: \(flips)")
        XCTAssertGreaterThan(e.x, 500)
        XCTAssertGreaterThan(e.y, 500)
    }

    func testGenuineTurnStillAdopts() {
        // A real 90° turn must show within ~100ms (6 ticks @16ms).
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 900; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<10 {
            e.update(dtMs: 16, mouse: CGPoint(x: 0, y: 0), visibleRect: rect)
        }
        XCTAssertEqual(e.state, .e)
        e.targetX = 500; e.targetY = 900 // hard turn north
        for _ in 0..<10 {
            e.update(dtMs: 16, mouse: CGPoint(x: 0, y: 0), visibleRect: rect)
        }
        XCTAssertEqual(e.state, .n)
    }

    // MARK: - Life: chatter, mood, energy, pounce, falls, social

    func testGrabChatterAndMood() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.beginDrag(mouseScreen: CGPoint(x: 500, y: 500))
        XCTAssertNotNil(e.speech)
        let before = e.mood
        e.interact()
        XCTAssertGreaterThan(e.mood, before)
    }

    func testEnergyMultipliers() {
        XCTAssertEqual(PetEngine.energyMultiplier(hour: 3), 0.8, accuracy: 0.001)
        XCTAssertEqual(PetEngine.energyMultiplier(hour: 8), 1.2, accuracy: 0.001)
        XCTAssertEqual(PetEngine.energyMultiplier(hour: 14), 1.0, accuracy: 0.001)
    }

    func testHappyMoodZoomies() {
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var fast = PetEngine(x: 500, y: 500)
        fast.hourOverride = 12; fast.mood = 100
        fast.targetX = 1500; fast.targetY = 500
        var slow = PetEngine(x: 500, y: 500)
        slow.hourOverride = 12; slow.mood = 70
        slow.targetX = 1500; slow.targetY = 500
        for _ in 0..<60 {
            fast.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            slow.update(dtMs: 16, mouse: .zero, visibleRect: rect)
        }
        XCTAssertGreaterThan(fast.x - 500, (slow.x - 500) * 1.2)
    }

    func testPounceAtNearCursor() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<500 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        XCTAssertEqual(e.state, .idle)
        let x0 = e.x
        for _ in 0..<20 {
            e.update(dtMs: 16, mouse: CGPoint(x: 560, y: 500), visibleRect: rect)
        }
        XCTAssertGreaterThan(e.x, x0 + 5)
        XCTAssertEqual(e.speech, "!")
    }

    func testFlingFallsAndLands() {
        var e = PetEngine(x: 500, y: 800)
        e.hourOverride = 12
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        e.beginDrag(mouseScreen: CGPoint(x: 500, y: 800))
        e.endDrag(in: rect, releaseVelocity: CGVector(dx: 100, dy: -600))
        XCTAssertTrue(e.falling)
        var landed = false
        for _ in 0..<600 {
            e.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            if !e.falling { landed = true; break }
        }
        XCTAssertTrue(landed)
        XCTAssertEqual(e.speech, "whee!")
        XCTAssertEqual(e.y, 32, accuracy: 1.0)
    }

    func testGentleReleaseDoesNotFall() {
        var e = PetEngine(x: 500, y: 800)
        e.hourOverride = 12
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        e.beginDrag(mouseScreen: CGPoint(x: 500, y: 800))
        e.endDrag(in: rect, releaseVelocity: CGVector(dx: 10, dy: 10))
        XCTAssertFalse(e.falling)
        XCTAssertEqual(e.state, .idle)
    }

    func testSocialInviteMoves() {
        var e = PetEngine(x: 100, y: 100)
        e.hourOverride = 12
        e.targetX = 100; e.targetY = 100
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<500 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        e.inviteToChase(CGPoint(x: 400, y: 100), durationMs: 5000)
        let x0 = e.x
        for _ in 0..<30 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        XCTAssertGreaterThan(e.x, x0 + 10)
    }

    func testTickIntervals() {
        XCTAssertEqual(PetManager.tickInterval(walking: true, chasing: false,
            dragging: false, falling: false, sleeping: false), 1.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(PetManager.tickInterval(walking: false, chasing: false,
            dragging: false, falling: false, sleeping: true), 1.0, accuracy: 0.001)
        XCTAssertEqual(PetManager.tickInterval(walking: false, chasing: false,
            dragging: false, falling: false, sleeping: false), 0.1, accuracy: 0.001)
    }

    func testZzzField() {
        var z = ZzzField()
        for _ in 0..<40 { z.update(dtMs: 100, active: false) }
        XCTAssertTrue(z.parts.isEmpty)
        for _ in 0..<7 { z.update(dtMs: 100, active: true) }
        XCTAssertFalse(z.parts.isEmpty)
        let y0 = z.parts[0].y
        z.update(dtMs: 500, active: true)
        XCTAssertLessThan(z.parts[0].y, y0)
    }

    func testHeadAnchorFindsTop() {
        // Regression: the pixel reader once assumed bottom-up buffers and
        // tracked FEET instead of heads. Programmatic image, no fixtures.
        let img = NSImage(size: NSSize(width: 32, height: 32))
        img.lockFocus()
        NSColor.white.setFill()
        // lockFocus origin is bottom-left: y 20..26 => rows 6..12 from top.
        NSRect(x: 10, y: 20, width: 12, height: 6).fill()
        img.unlockFocus()
        let a = HeadAnchor.of(img)
        XCTAssertEqual(a.y, 6, accuracy: 0.6)
        XCTAssertEqual(a.x, 16, accuracy: 0.6)
    }

    func testEnabledOverlaysHaveNoGating() {
        // Product rule: enabled = displayed. Overlay carries no
        // seasons/species fields anymore — just a name and an image.
        let o = Overlay(name: "x", image: NSImage(size: NSSize(width: 1, height: 1)))
        XCTAssertEqual(o.name, "x")
    }

    func testLaserFormationDistinct() {
        let o0 = LaserFormation.offset(index: 0, count: 3, timeSeconds: 1.0)
        let o1 = LaserFormation.offset(index: 1, count: 3, timeSeconds: 1.0)
        XCTAssertGreaterThan(hypot(o0.dx - o1.dx, o0.dy - o1.dy), 20)
        XCTAssertEqual(LaserFormation.offset(index: 0, count: 1, timeSeconds: 5), .zero)
    }

    func testSeparationSplitsStacked() {
        let p = CGPoint(x: 100, y: 100)
        let (na, nb) = Separation.push(a: p, b: p)
        // Capped per-tick glide (no ±22pt teleport jitter), opposite sides.
        XCTAssertGreaterThan(na.dx, 0)
        XCTAssertLessThan(nb.dx, 0)
        XCTAssertLessThanOrEqual(abs(na.dx), 6.01)
        let (fa, fb) = Separation.push(a: CGPoint(x: 0, y: 0),
                                        b: CGPoint(x: 1000, y: 1000))
        XCTAssertEqual(fa.dx, 0, accuracy: 0.001)
        XCTAssertEqual(fb.dx, 0, accuracy: 0.001)
    }

    func testStallWatchdogReroutes() {
        // Pinned in place while walking -> must recover to idle + new target.
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 1500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var recovered = false
        for _ in 0..<600 {
            e.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            e.x = 500; e.y = 500 // external blockage
            if e.state == .idle { recovered = true; break }
        }
        XCTAssertTrue(recovered, "watchdog must break the treadmill")
    }

    func testSoundCues() {
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.beginDrag(mouseScreen: CGPoint(x: 500, y: 500))
        XCTAssertEqual(e.soundCue, .grab)
    }

    func testWallClingThenSettle() {
        var e = PetEngine(x: 1000, y: 1200)
        e.hourOverride = 12
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        e.beginDrag(mouseScreen: CGPoint(x: 1000, y: 1200))
        e.endDrag(in: rect, releaseVelocity: CGVector(dx: -800, dy: 50))
        var clung = false
        var settled = false
        for _ in 0..<3000 {
            e.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            if e.clinging { clung = true }
            if !e.falling && !e.clinging && e.state == .idle && e.y <= 33 {
                settled = true; break
            }
        }
        XCTAssertTrue(clung, "must grab the wall")
        XCTAssertTrue(settled, "must end settled")
    }

    func testLaserCatchFlash() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.chasing = true
        XCTAssertTrue(e.catchReady)
        e.playCatch(toward: CGPoint(x: 510, y: 505))
        XCTAssertEqual(e.state, .swat)
        XCTAssertFalse(e.catchReady)
    }

    func testSwatHoldsThenResumes() {
        // Modal flash: locomotion must NOT stomp it the next tick
        // (the old happy-while-chasing bug that hid laser catches).
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.chasing = true
        e.playCatch(toward: CGPoint(x: 600, y: 500))
        let x0 = e.x
        e.update(dtMs: 16, mouse: CGPoint(x: 900, y: 500),
                 visibleRect: CGRect(x: 0, y: 0, width: 2000, height: 2000))
        XCTAssertEqual(e.state, .swat)
        XCTAssertEqual(e.x, x0, accuracy: 0.001)
        for _ in 0..<60 {
            e.update(dtMs: 16, mouse: CGPoint(x: 900, y: 500),
                     visibleRect: CGRect(x: 0, y: 0, width: 2000, height: 2000))
        }
        XCTAssertNotEqual(e.state, .swat)
        XCTAssertGreaterThan(e.x, x0)
    }

    func testFallbackStates() {
        XCTAssertEqual(PetState.swat.fallbackState, .happy)
        XCTAssertEqual(PetState.clingSide.fallbackState, .dragged)
        XCTAssertEqual(PetState.clingTop.fallbackState, .dragged)
        XCTAssertNil(PetState.idle.fallbackState)
    }

    // MARK: - Awareness: ambient chatter, solicitation, greetings

    func testAmbientChatter() {
        var e = PetEngine(x: 1500, y: 1500)
        e.hourOverride = 12
        e.targetX = 1500; e.targetY = 1500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var heard: String? = nil
        for _ in 0..<6000 {
            e.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            if let s = e.speech, Config.ambientPhrases.contains(s) {
                heard = s; break
            }
        }
        XCTAssertNotNil(heard, "must talk unprompted eventually")
    }

    func testBegPatPurr() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let near = CGPoint(x: 600, y: 520)
        for _ in 0..<2500 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        XCTAssertEqual(e.state, .idle)
        var begged = false
        for _ in 0..<3000 {
            e.update(dtMs: 16, mouse: near, visibleRect: rect)
            if e.begging { begged = true; break }
        }
        XCTAssertTrue(begged, "must come asking for pats")
        let m0 = e.mood
        e.interact()
        XCTAssertGreaterThanOrEqual(e.mood, m0 + 15)
        XCTAssertTrue(e.purring)
        XCTAssertFalse(e.begging)
    }

    func testPetGreeting() {
        var a = PetEngine(x: 100, y: 100)
        a.hourOverride = 12
        a.targetX = 100; a.targetY = 100
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<300 { a.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        a.greet()
        XCTAssertEqual(a.state, .happy)
        XCTAssertTrue(Config.greetPhrases.contains(a.speech ?? ""))
    }

    func testFeedBoostsAndWakes() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.mood = 95
        e.feed()
        XCTAssertEqual(e.mood, 100, accuracy: 0.001)
        XCTAssertEqual(e.speech, "nom!!")
        var s = PetEngine(x: 500, y: 500)
        s.hourOverride = 12
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        s.toggleFreeze()
        for _ in 0..<400 { s.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        XCTAssertEqual(s.state, .sleeping)
        s.feed()
        XCTAssertFalse(s.frozen)
        XCTAssertEqual(s.speech, "FOOD?!")
    }

    func testNuzzleWiggleAndCooldown() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<300 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        e.nuzzle()
        XCTAssertEqual(e.state, .happy)
        XCTAssertEqual(e.mood, 73, accuracy: 0.001)
        e.soundCue = nil
        e.nuzzle()
        XCTAssertNil(e.soundCue, "hover cooldown gates repeat chirps")
    }

    func testMoodWords() {
        XCTAssertEqual(Config.moodWord(90), "blissful")
        XCTAssertEqual(Config.moodWord(70), "happy")
        XCTAssertEqual(Config.moodWord(50), "content")
        XCTAssertEqual(Config.moodWord(30), "drowsy")
        XCTAssertEqual(Config.moodWord(10), "grumpy")
    }

    func testZoomiesFireOnTrips() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.mood = 90
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<1400 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        var seen = false
        for _ in 0..<20 {
            e.pickRandomDestination(in: rect, margin: 100)
            if e.speech == "ZOOMIES!!" { seen = true; break }
            for _ in 0..<1300 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        }
        XCTAssertTrue(seen, "frisky pets must zoom eventually")
    }

    // MARK: - Social: dialogue, startle, grooming

    func testDialogueRunner() {
        var d = DialogueRunner()
        XCTAssertFalse(d.start(participants: [7]))
        XCTAssertTrue(d.start(participants: [0, 1]))
        var got: [(Int, String)] = []
        for _ in 0..<10 { got += d.update(dtMs: 1000) }
        XCTAssertEqual(got.count, 3)
        XCTAssertEqual(got[0].0, 0)
        XCTAssertEqual(got[1].0, 1)
        XCTAssertEqual(got[2].0, 0)
        XCTAssertFalse(d.isRunning)
    }

    func testStartleFlinch() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        for _ in 0..<300 { e.update(dtMs: 16, mouse: .zero, visibleRect: rect) }
        XCTAssertEqual(e.state, .idle)
        e.update(dtMs: 16, mouse: CGPoint(x: 520, y: 500), visibleRect: rect)
        e.update(dtMs: 16, mouse: CGPoint(x: 700, y: 500), visibleRect: rect)
        XCTAssertTrue(e.speech == "whoa!" || e.speech == "EEP.")
        XCTAssertEqual(e.state, .idle, "flinch holds idle")
    }

    func testGroomingHappens() {
        var e = PetEngine(x: 500, y: 500)
        e.hourOverride = 12
        e.targetX = 500; e.targetY = 500
        let rect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        var groomed = false
        for _ in 0..<8000 {
            e.update(dtMs: 16, mouse: .zero, visibleRect: rect)
            if let s = e.speech, Config.groomPhrases.contains(s) {
                groomed = true; break
            }
        }
        XCTAssertTrue(groomed, "long idles must include a spa break")
    }
}
