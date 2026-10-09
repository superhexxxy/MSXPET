// AnimationLoader: loads PNG frames from .app Resources or SwiftPM Bundle.module.
// Falls back to procedurally drawn placeholders so M0 runs without assets.
// Real assets: run Tools/convert_assets.py on upstream pets/*.xpm -> Resources/pets/.

import AppKit
import Foundation

public enum AnimationLoader {
    public static func loadFrames(petName: String, state: PetState) -> [NSImage] {
        for base in AppResources.bases() {
            // Try: <base>/pets/<pet>/<state>/0.png, 1.png ...
            var frames: [NSImage] = []
            for i in 0..<64 {
                let url = base.appendingPathComponent("pets/\(petName)/\(state.assetDirectoryName)/\(i).png")
                if let img = NSImage(contentsOf: url) { frames.append(img) }
                else { break }
            }
            if !frames.isEmpty { return frames }
        }
        return []
    }

    public static func placeholderFrames(for state: PetState, size: CGFloat = 64) -> [NSImage] {
        // Simple coloured circle/square so window is visible pre-assets.
        let color: NSColor = switch state {
        case .sleeping: .systemBlue
        case .happy: .systemPink
        case .dragged: .systemOrange
        case .idle: .systemGray
        default: .black
        }
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        color.setFill()
        let rect = NSRect(x: 8, y: 8, width: size - 16, height: size - 16)
        if state == .sleeping {
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            ("Z" as NSString).draw(at: NSPoint(x: size/2-6, y: size/2-8),
                                   withAttributes: [.foregroundColor: NSColor.white])
        } else {
            NSBezierPath(ovalIn: rect).fill()
            NSColor.white.setFill()
            let eye = NSRect(x: size/2-10, y: size/2+2, width: 5, height: 7)
            NSBezierPath(ovalIn: eye).fill()
            NSBezierPath(ovalIn: eye.offsetBy(dx: 14, dy: 0)).fill()
        }
        img.unlockFocus()
        return [img]
    }
}

/// Shared resource lookup: .app bundle first, then SwiftPM module bundle,
/// then dev-checkout fallbacks. Used by animation, sound, and overlays.
public enum AppResources {
    public static func bases() -> [URL] {
        var bases: [URL] = []
        if let r = Bundle.main.resourceURL { bases.append(r) }
        #if SWIFT_PACKAGE
        bases.append(Bundle.module.resourceURL ?? Bundle.module.bundleURL)
        #endif
        // Dev fallback: Sources/MSXPET/Resources next to checkout
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        bases.append(cwd.appendingPathComponent("Sources/MSXPET/Resources"))
        bases.append(cwd.appendingPathComponent("Resources"))
        return bases
    }
}
