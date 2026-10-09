// MSXPET — macOS native desktop pet (Apple Silicon / ARM64)
// Faithful AppKit port of https://github.com/uint23/xpet (GPL-3.0).
//
// Config mirrors upstream `config.h`. All time values are milliseconds
// unless noted. Speeds are points-per-second (upstream used px-per-tick).

import Foundation
import CoreGraphics

public enum Config {
    public static let petSize: CGFloat = 64
    public static let petSpeedPointsPerSecond: CGFloat = 100 // 20px / 200ms upstream
    public static let tickInterval: TimeInterval = 1.0 / 60.0

    public static let unfreezeDelayMs: Int = 2000
    public static let wanderMinWaitMs: Int = 16000
    public static let wanderMaxWaitMs: Int = 32000
    public static let wanderMargin: CGFloat = 100

    public static let sleepDelayMs: Int = 5000
    public static let happyDurationMs: Int = 3000
    public static let swatDurationMs: Int = 700
    public static let speechDurationMs: Int = 3000

    public static let frameDurationMs: Int = 200
    public static let speechPadX: CGFloat = 8
    public static let speechPadY: CGFloat = 6

    public static let petName = "neko"
    public static let availablePets = ["neko", "bsd", "dog"]
    public static let selectedPetKey = "MSXPET.pet"
    public static let nameKey = "MSXPET.name"
    public static let laserKey = "MSXPET.laser"
    public static let countKey = "MSXPET.count"
    public static let soundKey = "MSXPET.sound"
    public static let accessoriesKey = "MSXPET.accessories"
    public static let petPhrases: [String] = [
        "hewwo :3",
        "*purrs*",
        "did someone say snacks?",
        "i live here now",
        "boop.",
        "nap time? nap time.",
    ]
}
