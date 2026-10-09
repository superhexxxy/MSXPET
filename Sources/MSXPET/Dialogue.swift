// Dialogue: scripted micro-exchanges between pets. Pure timing + scripts —
// the manager pumps update() and delivers due lines via engine.say().
// No AppKit — fully unit-testable.

import Foundation

public struct DialogueRunner {
    public static let scripts: [[String]] = [
        ["psst.", "what.", "…nothing. ♥"],
        ["i saw the laser first.", "did not.", "did too."],
        ["nap after?", "nap now.", "same."],
        ["u smell like outside.", "u smell like inside.", "fair."],
        ["race u there.", "ur on.", "* already running *"],
        ["my human's cuter.", "NUH UH.", "…yours is ok too."],
    ]

    private var pending: [(pet: Int, line: String, dueMs: Int)] = []
    private var clockMs = 0

    public init() {}

    public var isRunning: Bool { !pending.isEmpty }

    /// Start a random script across participants (cycled A/B/A…).
    @discardableResult
    public mutating func start(participants: [Int]) -> Bool {
        guard pending.isEmpty, participants.count >= 2,
              let script = Self.scripts.randomElement() else { return false }
        var t = clockMs
        for (k, line) in script.enumerated() {
            pending.append((participants[k % participants.count], line, t))
            t += 1800
        }
        return true
    }

    /// Due lines as (petIndex, line). Call every tick.
    public mutating func update(dtMs: Int) -> [(Int, String)] {
        clockMs += dtMs
        let due = pending.filter { $0.dueMs <= clockMs }.map { ($0.pet, $0.line) }
        pending.removeAll { $0.dueMs <= clockMs }
        return due
    }
}
