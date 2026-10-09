// Formation: pure helpers so laser-chasing pets swarm instead of stacking.
// No AppKit — fully unit-testable.

import CoreGraphics
import Foundation

public enum LaserFormation {
    /// Personal offset around the laser point: each pet aims at its own
    /// spot on a slowly rotating ring, so N pets never share a pixel.
    public static func offset(index: Int, count: Int, timeSeconds: CGFloat,
                              radius: CGFloat = 30) -> CGVector {
        guard count > 1 else { return .zero }
        let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi + timeSeconds * 0.9
        return CGVector(dx: cos(angle) * radius, dy: sin(angle) * radius * 0.7)
    }
}

public enum Separation {
    /// Push two pets apart when closer than minDist. Returns nudges
    /// (dx, dy) to ADD to (a, b) respectively. Pure — caller applies.
    public static func push(a: CGPoint, b: CGPoint, minDist: CGFloat = 44)
        -> (CGVector, CGVector) {
        let dx = a.x - b.x, dy = a.y - b.y
        let dist = hypot(dx, dy)
        guard dist < minDist else { return (.zero, .zero) }
        if dist < 0.001 {
            // Exactly stacked: split along x deterministically.
            return (CGVector(dx: minDist / 2, dy: 0), CGVector(dx: -minDist / 2, dy: 0))
        }
        let push = (minDist - dist) / 2
        let nx = dx / dist * push, ny = dy / dist * push
        return (CGVector(dx: nx, dy: ny), CGVector(dx: -nx, dy: -ny))
    }
}
