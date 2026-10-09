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
}
