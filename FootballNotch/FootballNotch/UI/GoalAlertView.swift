import SwiftUI

struct GoalAlertView: View {
    let event: GoalEvent
    let match: Match
    let supportedTeamID: String?

    private var isForSupportedTeam: Bool {
        switch event.side {
        case .home: return match.homeTeam.id == supportedTeamID
        case .away: return match.awayTeam.id == supportedTeamID
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(isForSupportedTeam ? "⚽️🎉 GOAL!" : "⚽️😬 Conceded")
                .font(.system(size: 13, weight: .bold))
            Text("\(match.homeTeam.shortName) \(event.newHomeScore) - \(event.newAwayScore) \(match.awayTeam.shortName)")
                .font(.system(size: 11))
                .monospacedDigit()
        }
        .padding(16)
        .frame(width: 220, height: 70)
        .background(isForSupportedTeam ? Color.green.opacity(0.85) : Color.red.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            GoalSoundPlayer.play(isForSupportedTeam: isForSupportedTeam)
        }
    }
}
