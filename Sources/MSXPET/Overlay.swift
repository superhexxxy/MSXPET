// Overlay: full-canvas 32x32 accessory layers drawn over the sprite.
// Simple rule: enabled = displayed. No seasons, no species gating.
// Sources: bundled Resources/overlays/<name>/{overlay.png, meta.json}
// plus ~/Library/Application Support/MSXPET/Overlays/<name>/ (user wins).

import AppKit
import Foundation

public struct Overlay: Equatable {
    public var name: String
    public var image: NSImage
    /// Directional variants, keyed by state directory name
    /// (e.g. "walk_east"). Exact match first, then facing fallback
    /// (diagonals borrow their cardinal: ne/se→east, nw/sw→west).
    public var variants: [String: NSImage] = [:]

    public static func == (lhs: Overlay, rhs: Overlay) -> Bool {
        lhs.name == rhs.name
    }

    public func image(for stateDir: String, frame: Int = 0) -> NSImage {
        // Most specific first: exact frame, then state, then facing
        // (diagonals borrow their cardinal), then the default art.
        if let v = variants["\(stateDir)_\(frame)"] { return v }
        if let v = variants[stateDir] { return v }
        let facing: [String: String] = [
            "walk_northeast": "walk_east", "walk_southeast": "walk_east",
            "walk_northwest": "walk_west", "walk_southwest": "walk_west",
        ]
        if let f = facing[stateDir] {
            if let v = variants["\(f)_\(frame)"] { return v }
            if let v = variants[f] { return v }
        }
        return image
    }
}

public enum OverlayLoader {
    public static var userDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("MSXPET/Overlays", isDirectory: true)
    }()

    public static func loadAll() -> [Overlay] {
        var byName: [String: Overlay] = [:]
        // Bundled first, user files override same names.
        for base in AppResources.bases() {
            load(from: base.appendingPathComponent("overlays"), into: &byName)
        }
        load(from: userDir, into: &byName)
        return byName.values.sorted { $0.name < $1.name }
    }

    private static func load(from dir: URL, into dict: inout [String: Overlay]) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        for name in names.sorted() {
            let folder = dir.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            let imgURL = folder.appendingPathComponent("overlay.png")
            guard let image = NSImage(contentsOf: imgURL) else { continue }
            // Directional variants: <state>.png next to overlay.png.
            var variants: [String: NSImage] = [:]
            if let files = try? fm.contentsOfDirectory(atPath: folder.path) {
                for file in files where file.hasSuffix(".png") && file != "overlay.png" {
                    let key = String(file.dropLast(4)) // walk_east.png -> walk_east
                    if let vimg = NSImage(contentsOf: folder.appendingPathComponent(file)) {
                        variants[key] = vimg
                    }
                }
            }
            dict[name] = Overlay(name: name, image: image, variants: variants)
        }
    }

    public static func revealFolder() {
        try? FileManager.default.createDirectory(at: userDir,
                                                 withIntermediateDirectories: true)
        NSWorkspace.shared.open(userDir)
    }
}

/// Head-tracking anchor: the head bobs ±3px between animation frames while
/// overlays are static sheets — without correction hats float off mid-stride
/// (measured walk_east x: 13 → 9.5). The anchor (topmost opaque band centroid)
/// is precomputed once per frame; overlays shift by (frame − reference).
/// Coordinates: 32px art space, y-down from top.
public enum HeadAnchor {
    public static func of(_ image: NSImage) -> CGPoint {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CGPoint(x: 16, y: 0)
        }
        return averageAnchor(w: cg.width, h: cg.height, image: cg)
    }

    private static func averageAnchor(w: Int, h: Int, image: CGImage) -> CGPoint {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        var ok = false
        rgba.withUnsafeMutableBytes { ptr in
            if let ctx = CGContext(data: ptr.baseAddress, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: cs, bitmapInfo: info.rawValue) {
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                ok = true
            }
        }
        guard ok else { return CGPoint(x: CGFloat(w) / 2, y: 0) }
        // NOTE: empirically, buffers drawn this way are TOP-down
        // (row 0 = image top) — verified byte-for-byte against PIL.
        // Do NOT flip: ty == buffer row.
        var minY = h
        for ty in 0..<h {
            for x in 0..<w where rgba[(ty * w + x) * 4 + 3] > 20 {
                minY = min(minY, ty)
            }
        }
        var sumX = 0, n = 0
        for ty in minY...min(minY + 2, h - 1) {
            for x in 0..<w where rgba[(ty * w + x) * 4 + 3] > 20 {
                sumX += x; n += 1
            }
        }
        guard n > 0 else { return CGPoint(x: CGFloat(w) / 2, y: 0) }
        return CGPoint(x: CGFloat(sumX) / CGFloat(n), y: CGFloat(minY))
    }
}
