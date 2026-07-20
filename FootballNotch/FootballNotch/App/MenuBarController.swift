import AppKit

/// The app is otherwise invisible by design (LSUIElement: no Dock icon, no
/// regular window, no ⌘Tab presence) so the notch overlay itself never
/// looks like "a normal app". Without something in the actual system menu
/// bar, there was no way at all to quit it short of Activity Monitor or
/// killall — this is that control, kept intentionally minimal (quit only;
/// the notch panel itself is the whole UI).
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⚽️"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Football Notch", action: nil, keyEquivalent: ""))
        menu.items.first?.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Football Notch", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
