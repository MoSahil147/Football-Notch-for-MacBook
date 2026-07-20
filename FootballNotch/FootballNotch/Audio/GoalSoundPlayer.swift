import AppKit

/// Originally looked for bundled custom audio files (goal_celebration.caf /
/// goal_concede.caf) that were never actually sourced — meaning no goal
/// sound ever played, silently, since the missing-asset guard just no-opped.
/// Uses macOS's built-in system sounds instead: no custom audio assets are
/// bundled, same constraint as UISoundPlayer.
enum GoalSoundPlayer {
    static func systemSoundName(isForSupportedTeam: Bool) -> String {
        isForSupportedTeam ? "Hero" : "Basso"
    }

    static func play(isForSupportedTeam: Bool) {
        NSSound(named: systemSoundName(isForSupportedTeam: isForSupportedTeam))?.play()
    }

    /// Full-time result sound — same Hero/Basso pair as the per-goal sounds
    /// (won = happy, lost = sad), just for the match ending rather than an
    /// individual goal. A draw plays nothing (neither clearly happy nor sad).
    static func play(outcome: MatchOutcome) {
        switch outcome {
        case .won: play(isForSupportedTeam: true)
        case .lost: play(isForSupportedTeam: false)
        case .drew: break
        }
    }
}
