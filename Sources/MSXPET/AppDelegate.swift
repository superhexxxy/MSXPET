// AppDelegate: LSUIElement background app + menu-bar control.
// No global key monitor (avoids Accessibility permission friction);
// chase/freeze/pet-switch/quit live in the status-item menu.

import AppKit
import ServiceManagement

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: PetManager?
    private var statusItem: NSStatusItem?
    private var petItems: [String: NSMenuItem] = [:]
    private var countItems: [Int: NSMenuItem] = [:]
    private var loginItem: NSMenuItem?
    private var laserItem: NSMenuItem?
    private var soundItem: NSMenuItem?
    private var accessoriesRoot: NSMenuItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        let saved = UserDefaults.standard.string(forKey: Config.selectedPetKey)
            ?? Config.petName
        manager = PetManager(petName: Config.availablePets.contains(saved) ? saved : Config.petName)
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "MSXPET")
        }
        let menu = NSMenu()

        let petMenu = NSMenu()
        for name in Config.availablePets {
            let item = NSMenuItem(title: name.capitalized, action: #selector(selectPet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = (name == manager?.petName) ? .on : .off
            petMenu.addItem(item)
            petItems[name] = item
        }
        let petRoot = NSMenuItem(title: "Pet", action: nil, keyEquivalent: "")
        petRoot.submenu = petMenu
        menu.addItem(petRoot)

        let countMenu = NSMenu()
        for n in 1...3 {
            let item = NSMenuItem(title: n == 1 ? "1 pet" : "\(n) pets",
                                  action: #selector(selectCount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = n
            item.state = (n == (manager?.petCount ?? 1)) ? .on : .off
            countMenu.addItem(item)
            countItems[n] = item
        }
        let countRoot = NSMenuItem(title: "Clowder", action: nil, keyEquivalent: "")
        countRoot.submenu = countMenu
        menu.addItem(countRoot)

        accessoriesRoot = NSMenuItem(title: "Accessories", action: nil, keyEquivalent: "")
        menu.addItem(accessoriesRoot!)
        refreshAccessories()
        menu.addItem(.separator())

        let chase = NSMenuItem(title: "Toggle Chase", action: #selector(toggleChase), keyEquivalent: "c")
        chase.target = self
        menu.addItem(chase)
        let freeze = NSMenuItem(title: "Toggle Freeze / Sleep", action: #selector(toggleFreeze), keyEquivalent: "s")
        freeze.target = self
        menu.addItem(freeze)
        laserItem = NSMenuItem(title: "Laser Pointer", action: #selector(toggleLaser), keyEquivalent: "l")
        laserItem?.target = self
        menu.addItem(laserItem!)
        soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem?.target = self
        soundItem?.state = (manager?.soundEnabled ?? true) ? .on : .off
        menu.addItem(soundItem!)
        let soundsMenu = NSMenu()
        let reveal = NSMenuItem(title: "Reveal Sounds Folder…", action: #selector(revealSounds), keyEquivalent: "")
        reveal.target = self
        soundsMenu.addItem(reveal)
        let customRoot = NSMenuItem(title: "Custom Sounds", action: nil, keyEquivalent: "")
        customRoot.submenu = soundsMenu
        menu.addItem(customRoot)
        menu.addItem(.separator())

        let rename = NSMenuItem(title: "Rename…", action: #selector(rename), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)

        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem?.target = self
        loginItem?.state = loginEnabled() ? .on : .off
        menu.addItem(loginItem!)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MSXPET", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        laserItem?.state = (manager?.laserOn ?? false) ? .on : .off
        statusItem?.menu = menu
    }

    @objc private func selectPet(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        manager?.switchPet(name)
        for (n, item) in petItems { item.state = (n == name) ? .on : .off }
    }

    @objc private func selectCount(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? Int else { return }
        manager?.setCount(n)
        for (k, item) in countItems { item.state = (k == n) ? .on : .off }
    }

    private func refreshAccessories() {
        let m = NSMenu()
        for (name, enabled) in manager?.overlayList() ?? [] {
            let pretty = name.replacingOccurrences(of: "_", with: " ").capitalized
            let item = NSMenuItem(title: pretty, action: #selector(toggleAccessory(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = enabled ? .on : .off
            m.addItem(item)
        }
        m.addItem(.separator())
        let reload = NSMenuItem(title: "Reload Assets", action: #selector(reloadAssets),
                                keyEquivalent: "")
        reload.target = self
        m.addItem(reload)
        let reveal = NSMenuItem(title: "Reveal Overlays Folder…",
                                action: #selector(revealOverlays), keyEquivalent: "")
        reveal.target = self
        m.addItem(reveal)
        accessoriesRoot?.submenu = m
    }

    @objc private func toggleAccessory(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let on = sender.state != .on
        manager?.setOverlay(name, on: on)
        sender.state = on ? .on : .off
    }

    @objc private func reloadAssets() {
        manager?.reloadOverlays()
        refreshAccessories()
    }

    @objc private func revealOverlays() { OverlayLoader.revealFolder() }

    @objc private func toggleChase() { manager?.toggleChase() }
    @objc private func toggleFreeze() { manager?.toggleFreeze() }
    @objc private func toggleLaser() {
        let on = !(manager?.laserOn ?? false)
        manager?.setLaser(on)
        laserItem?.state = on ? .on : .off
    }
    @objc private func toggleSound() {
        let on = !(manager?.soundEnabled ?? true)
        manager?.setSound(on)
        soundItem?.state = on ? .on : .off
    }
    @objc private func revealSounds() { SoundManager.revealFolder() }
    @objc private func rename() {
        let alert = NSAlert()
        alert.messageText = "Name your pet"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = UserDefaults.standard.string(forKey: Config.nameKey) ?? ""
        field.placeholderString = "neko"
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if name.isEmpty {
                UserDefaults.standard.removeObject(forKey: Config.nameKey)
            } else {
                UserDefaults.standard.set(name, forKey: Config.nameKey)
            }
        }
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - Login item (macOS 13+, no entitlement needed for non-sandboxed app)

    private func loginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    loginItem?.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    loginItem?.state = .on
                }
            } catch {
                NSSound.beep()
            }
        }
    }
}
