// AppDelegate: LSUIElement background app + menu-bar control.
// No global key monitor in M0 (avoids Accessibility permission friction);
// chase/freeze/quit live in the status-item menu.

import AppKit

@main
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: PetManager?
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        setupStatusBar()
        manager = PetManager()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "MSXPET")
        }
        let menu = NSMenu()
        let chase = NSMenuItem(title: "Toggle Chase", action: #selector(toggleChase), keyEquivalent: "c")
        chase.target = self
        menu.addItem(chase)
        let freeze = NSMenuItem(title: "Toggle Freeze / Sleep", action: #selector(toggleFreeze), keyEquivalent: "s")
        freeze.target = self
        menu.addItem(freeze)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MSXPET", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func toggleChase() { manager?.toggleChase() }
    @objc private func toggleFreeze() { manager?.toggleFreeze() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
