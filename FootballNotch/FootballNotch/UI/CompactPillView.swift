import SwiftUI

struct CompactPillView: View {
    let match: Match

    var body: some View {
        HStack(spacing: 6) {
            CrestImageView(team: match.homeTeam)
            Text("\(match.homeScore)-\(match.awayScore)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            CrestImageView(team: match.awayTeam)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.black)
        .clipShape(Capsule())
    }
}
