// AppDelegate: LSUIElement background app + menu-bar control.
// No global key monitor (avoids Accessibility permission friction);
// chase/freeze/pet-switch/quit live in the status-item menu.

import AppKit
import ServiceManagement

@main
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: PetManager?
    private var statusItem: NSStatusItem?
    private var petItems: [String: NSMenuItem] = [:]
    private var loginItem: NSMenuItem?

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
        menu.addItem(.separator())

        let chase = NSMenuItem(title: "Toggle Chase", action: #selector(toggleChase), keyEquivalent: "c")
        chase.target = self
        menu.addItem(chase)
        let freeze = NSMenuItem(title: "Toggle Freeze / Sleep", action: #selector(toggleFreeze), keyEquivalent: "s")
        freeze.target = self
        menu.addItem(freeze)
        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem?.target = self
        loginItem?.state = loginEnabled() ? .on : .off
        menu.addItem(loginItem!)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MSXPET", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func selectPet(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        manager?.switchPet(name)
        for (n, item) in petItems { item.state = (n == name) ? .on : .off }
    }

    @objc private func toggleChase() { manager?.toggleChase() }
    @objc private func toggleFreeze() { manager?.toggleFreeze() }
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
