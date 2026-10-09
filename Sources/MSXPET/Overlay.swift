// Overlay: full-canvas 32x32 accessory layers drawn over the sprite.
// Sources: bundled Resources/overlays/<name>/{overlay.png, meta.json}
// plus ~/Library/Application Support/MSXPET/Overlays/<name>/ (user wins).

import AppKit
import Foundation

public struct Overlay: Equatable {
    public var name: String
    public var image: NSImage
    public var months: [Int]?   // nil = year-round
    public var species: [String]? // nil = all pets

    public static func == (lhs: Overlay, rhs: Overlay) -> Bool {
        lhs.name == rhs.name
    }

    public func suits(petName: String, month: Int) -> Bool {
        if let m = months, !m.contains(month) { return false }
        if let s = species, !s.contains(petName) { return false }
        return true
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
            var months: [Int]? = nil
            var species: [String]? = nil
            if let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                months = json["months"] as? [Int]
                species = json["species"] as? [String]
            }
            dict[name] = Overlay(name: name, image: image,
                                 months: months, species: species)
        }
    }

    public static func revealFolder() {
        try? FileManager.default.createDirectory(at: userDir,
                                                 withIntermediateDirectories: true)
        NSWorkspace.shared.open(userDir)
    }
}
