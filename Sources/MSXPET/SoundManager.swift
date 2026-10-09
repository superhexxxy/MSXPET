// SoundManager: one-shot event sounds + a loopable sleep purr.
// Bundled synth WAVs live in Resources/sounds/; users override per-event by
// dropping "<event>.wav/.mp3/.m4a" into Application Support (see userDir).

import AppKit
import Foundation

public final class SoundManager {
    public static let appSupportSounds: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("MSXPET/Sounds", isDirectory: true)
    }()

    public var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Config.soundKey) }
    }

    private var purr: NSSound?
    private var purrPlaying = false

    public init() {
        enabled = UserDefaults.standard.object(forKey: Config.soundKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Config.soundKey)
        try? FileManager.default.createDirectory(at: Self.appSupportSounds,
                                                 withIntermediateDirectories: true)
    }

    // MARK: - Lookup (user files win over bundled)

    public func url(for event: SoundEvent) -> URL? {
        for ext in ["wav", "mp3", "m4a", "aiff"] {
            let custom = Self.appSupportSounds.appendingPathComponent("\(event.rawValue).\(ext)")
            if FileManager.default.fileExists(atPath: custom.path) { return custom }
        }
        for base in AppResources.bases() {
            let bundled = base.appendingPathComponent("sounds/\(event.rawValue).wav")
            if FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        }
        return nil
    }

    // MARK: - Playback

    public func play(_ event: SoundEvent) {
        guard enabled, let url = url(for: event) else { return }
        _ = NSSound(contentsOf: url, byReference: true)?.play()
    }

    /// Clean purr loop: single shared NSSound, loops=true, started/stopped
    /// only on transitions. Idempotent — safe to call every tick.
    public func setPurr(_ active: Bool) {
        let want = active && enabled
        if want == purrPlaying { return }
        purrPlaying = want
        if want {
            if purr == nil, let url = url(for: .purr) {
                purr = NSSound(contentsOf: url, byReference: true)
                purr?.loops = true
            }
            purr?.play()
        } else {
            purr?.stop()
        }
    }

    public func stopAll() {
        purr?.stop()
        purrPlaying = false
    }

    public static func revealFolder() {
        try? FileManager.default.createDirectory(at: appSupportSounds,
                                                 withIntermediateDirectories: true)
        NSWorkspace.shared.open(appSupportSounds)
    }
}
