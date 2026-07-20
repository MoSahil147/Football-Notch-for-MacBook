import SwiftUI

struct GoalAlertView: View {
    let event: GoalEvent
    let match: Match
    let supportedTeamID: String?

    // Entrance animation state: starts shrunk/invisible and springs to full
    // size on appear. Same spring for both outcomes — only color, text, and
    // sound differ between celebrating and conceding.
    @State private var hasAppeared = false

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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .scaleEffect(hasAppeared ? 1 : 0.4)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            GoalSoundPlayer.play(isForSupportedTeam: isForSupportedTeam)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                hasAppeared = true
            }
        }
    }
}
