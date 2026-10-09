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
        // pats (click)
        "hewwo :3", "*purrs*", "pawsome!!", "meowsome!!", "oemgi!!",
        "meowvelous.", "purrfection.", "ameowzing!!", "fur real?!",
        "cat-tastic!!", "meowgical~", "hehe!", "* headbutt *", "mrrp?",
        "again!! again!!", "my human!!", "best day ever", "soft.",
        "warm hands.", "10/10 pats", "* kneads *", "keep goin",
        "certified cute", "i woke up cute", "whisker check: fab",
        "toe beans out", "did someone say snacks?", "i live here now",
        "boop.", "mlem.", "* biscuit mode *", "u may continue.",
        "purrmission granted.", "head empty, only pats.", "living art.",
        "i'm the moment.", "feed me compliments.", "soft launch (me).",
    ]
    /// Unprompted attention-seeking lines (ambient timer, never on click).
    public static let ambientPhrases: [String] = [
        "* stares at you *", "do u see me?", "pspsps… urself, coward",
        "i'm right here??", "notice meeee", "am i cute tho. be honest.",
        "my whiskers today… flawless.", "i shined my beans",
        "what if *i* was the laser?", "zoomies later.", "thinking about fish.",
        "the red dot owes me money.", "i run this desktop.", "i saw that.",
        "u blinked first.", "tail says hi.", "professional loaf.",
        "i'm bored. entertain me.", "hey. heyheyheyheyhey.",
        "sniff sniff… u smell like outside.", "i cleaned ONE paw today.",
        "productivity.", "watching u work. judging. loving.",
        "my tail has its own plans.", "brb, staring at wall.",
        "i heard a wrapper. investigate?", "do fish dream? asking.",
        "today's forecast: loaf, then zoom.", "i pay rent in cute.",
    ]
    /// Solicitation: wants pats.
    public static let begPhrases: [String] = [
        "pats?", "psst. pats.", "pet tax due.", "ahem. pats pls.",
    ]
    public static let ignoredPhrases: [String] = [
        "fine.", "wow. ok.", "rude. (lovingly)",
    ]
    /// Greetings between pets.
    public static let greetPhrases: [String] = [
        "♥", "psps!", "heyy!!", "sisfur!!",
    ]
}
