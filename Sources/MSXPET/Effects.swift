// Effects: tiny pure helpers for cuteness. No AppKit — fully unit-testable.

import CoreGraphics
import Foundation

// MARK: - Sound cues (engine raises them; SoundManager plays them)

public enum SoundEvent: String, CaseIterable {
    case grab, happy, land, pounce, laserOn, laserOff, wake, purr
}
// MARK: - Sleeping Zzz particles (PetView draws them; view coords: y-down)

public struct ZParticle {
    public var x: CGFloat // 0...64
    public var y: CGFloat // starts near head, rises (decreases)
    public var ageMs: Int
    public var lifeMs: Int
    public var size: CGFloat

    public var alpha: CGFloat {
        max(0, 1 - CGFloat(ageMs) / CGFloat(lifeMs))
    }
}

public struct ZzzField {
    public var parts: [ZParticle] = []
    private var spawnAccumMs = 0
    private var sizeCycle = 0

    public init() {}

    public mutating func update(dtMs: Int, active: Bool) {
        if active {
            spawnAccumMs += dtMs
            if spawnAccumMs >= 600 {
                spawnAccumMs = 0
                sizeCycle = (sizeCycle + 1) % 3
                parts.append(ZParticle(
                    x: CGFloat.random(in: 22...42),
                    y: 16,
                    ageMs: 0,
                    lifeMs: 2400,
                    size: [8, 10, 12][sizeCycle]
                ))
            }
        } else {
            spawnAccumMs = 0
        }
        for i in parts.indices {
            parts[i].ageMs += dtMs
            parts[i].y -= CGFloat(dtMs) * 0.012 // float upward
        }
        parts.removeAll { $0.ageMs >= $0.lifeMs }
    }
}

// MARK: - Seasonal hats (drawn procedurally in PetView — no art pipeline)

public enum HatSeason {
    case none, santa, spooky

    public static func current(month: Int) -> HatSeason {
        switch month {
        case 12: return .santa
        case 10: return .spooky
        default: return .none
        }
    }
}
