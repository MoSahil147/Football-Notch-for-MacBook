import AppKit

/// Lightweight navigation feedback using macOS's built-in system sounds — no
/// custom audio assets are bundled (same constraint as GoalSoundPlayer), so
/// these reuse NSSound's named system sounds rather than invented placeholder
/// audio.
enum UISoundPlayer {
    static func playMatchSelected() {
        NSSound(named: "Pop")?.play()
    }
}
