import AppKit

// Explicit entry point: wire delegate manually instead of relying on
// NSApplicationMain nib magic (there is no MainMenu nib in this bundle).
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
