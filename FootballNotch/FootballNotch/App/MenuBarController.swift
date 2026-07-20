import AppKit

/// The app is otherwise invisible by design (LSUIElement: no Dock icon, no
/// regular window, no ⌘Tab presence) so the notch overlay itself never
/// looks like "a normal app". Without something in the actual system menu
/// bar, there was no way at all to quit it short of Activity Monitor or
/// killall — this is that control, kept intentionally minimal (quit only;
/// the notch panel itself is the whole UI).
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        // A plain (non-NSObject) Swift class as an NSMenuItem's target
        // doesn't reliably participate in Cocoa's target-action dispatch,
        // which goes through the Objective-C runtime — inheriting NSObject
        // (above) is what makes the Quit item's target/action actually work.
        statusItem.button?.title = "⚽️"

        let menu = NSMenu()
        let header = NSMenuItem(title: "Football Notch", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Football Notch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
