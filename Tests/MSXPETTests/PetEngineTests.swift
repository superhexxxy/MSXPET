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
        e.beginDrag()
        XCTAssertEqual(e.state, .dragged)
        e.dragBy(dx: 10, dy: 20)
        XCTAssertEqual(e.x, 110, accuracy: 0.01)
        e.endDrag(in: rect)
        XCTAssertEqual(e.state, .idle)
        XCTAssertFalse(e.dragging)
    }

    func testChaseMovesTowardMouse() {
        var e = PetEngine(x: 0, y: 0)
        e.chasing = true
        let rect = CGRect(x: -1000, y: -1000, width: 3000, height: 3000)
        e.update(dtMs: 200, mouse: CGPoint(x: 500, y: 0), visibleRect: rect)
        XCTAssertGreaterThan(e.x, 0)
        XCTAssertEqual(e.state, .e)
    }
}
