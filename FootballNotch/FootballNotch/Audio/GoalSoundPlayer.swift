import AVFoundation

enum GoalSoundPlayer {
    private static var player: AVAudioPlayer?

    static func soundFileName(isForSupportedTeam: Bool) -> String {
        isForSupportedTeam ? "goal_celebration.caf" : "goal_concede.caf"
    }

    static func play(isForSupportedTeam: Bool) {
        let fileName = soundFileName(isForSupportedTeam: isForSupportedTeam)
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else {
            return // Missing sound asset must never crash the app.
        }
        player = audioPlayer
        player?.play()
    }
}
